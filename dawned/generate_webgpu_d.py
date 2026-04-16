#!/usr/bin/env python3
"""
Generates D binds for Dawn
"""
import json
from collections import OrderedDict
from typing import Optional, List, Dict, Any

def to_camelCase(s: str) -> str:
    parts = s.split(' ')
    return parts[0].lower() + ''.join(p.capitalize() for p in parts[1:])

def to_PascalCase(s: str) -> str:
    return ''.join(p.capitalize() for p in s.split(' '))


# Map dawn.json types to D types
PRIMITIVE_TYPE_MAP = {
    'bool': 'WGPUBool',
    'float': 'float',
    'double': 'double',
    'int': 'int',
    'int8_t': 'int8_t',
    'uint8_t': 'uint8_t',
    'int16_t': 'int16_t',
    'uint16_t': 'uint16_t',
    'int32_t': 'int32_t',
    'uint32_t': 'uint32_t',
    'int64_t': 'int64_t',
    'uint64_t': 'uint64_t',
    'size_t': 'size_t',
    'void': 'void',
    'void *': 'void*',
    'void const *': 'const(void)*',
    'char': 'char',
}

# Map C constant macros to D equivalents
C_CONSTANT_MAP = {
    'UINT64_MAX': 'uint64_t.max',
    'UINT32_MAX': 'uint32_t.max',
    'SIZE_MAX': 'size_t.max',
    'NAN': 'float.nan',
}

# D reserved words that need escaping
D_KEYWORDS = {
    'abstract', 'alias', 'align', 'asm', 'assert', 'auto',
    'body', 'bool', 'break', 'byte',
    'case', 'cast', 'catch', 'cdouble', 'cent', 'cfloat', 'char', 'class', 'const', 'continue', 'creal',
    'dchar', 'debug', 'default', 'delegate', 'delete', 'deprecated', 'do', 'double',
    'else', 'enum', 'export', 'extern',
    'false', 'final', 'finally', 'float', 'for', 'foreach', 'foreach_reverse', 'function',
    'goto',
    'idouble', 'if', 'ifloat', 'immutable', 'import', 'in', 'inout', 'int', 'interface', 'invariant', 'ireal', 'is',
    'lazy', 'long',
    'macro', 'mixin', 'module',
    'new', 'nothrow', 'null',
    'out', 'override',
    'package', 'pragma', 'private', 'protected', 'public', 'pure',
    'real', 'ref', 'return',
    'scope', 'shared', 'short', 'static', 'struct', 'super', 'switch', 'synchronized',
    'template', 'this', 'throw', 'true', 'try', 'typedef', 'typeid', 'typeof',
    'ubyte', 'ucent', 'uint', 'ulong', 'union', 'unittest', 'ushort',
    'version', 'void', 'volatile',
    'wchar', 'while', 'with',
    '__FILE__', '__LINE__', '__gshared', '__traits', '__vector',
}

def escape_d_keyword(name: str) -> str:
    """Escape D keywords and invalid identifiers."""
    if name in D_KEYWORDS:
        return name + '_'
    if name and name[0].isdigit():
        return '_' + name
    return name

def d_name(s: str) -> str:
    """Convert a dawn.json name to a valid D identifier."""
    return escape_d_keyword(to_camelCase(s))

def _is_enabled(tags: list) -> bool:
    """Return False only for emscripten-only items."""
    return not (tags and 'emscripten' in tags and 'dawn' not in tags and 'native' not in tags)

def _tag_value_prefix(tags: list) -> int:
    """Numeric offset to apply to a value based on its extension tag."""
    if 'compat' in tags:     return 0x00020000
    if 'dawn' in tags:       return 0x00050000
    if 'emscripten' in tags: return 0x00040000
    if 'native' in tags:     return 0x00010000
    return 0

def _parse_args(json_args: list) -> list:
    """Normalize a JSON args list into dicts with 'name', 'type', 'annotation'."""
    return [
        {
            'name': a['name'],
            'type': a['type'],
            'annotation': a.get('annotation', ''),
        }
        for a in json_args
    ]


# =============================================================================
# JSON Model Classes
# =============================================================================

class DawnType:
    """Base class for all types in dawn.json."""

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        self.json_name = name
        self.category = json_data.get('category', '')
        self.tags = json_data.get('tags', [])
        self.generator = generator

    def is_enabled(self) -> bool:
        return _is_enabled(self.tags)

    def d_type_name(self) -> str:
        return self.generator.type_prefix + to_PascalCase(self.json_name)

    def base_name(self) -> str:
        return to_PascalCase(self.json_name)


class EnumType(DawnType):
    """Enum type (non-bitmask)."""

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        self.values = []
        self.has_undefined = False

        for v in json_data.get('values', []):
            tags = v.get('tags', [])
            if not _is_enabled(tags):
                continue
            value = v.get('value')
            if value is not None:
                value += _tag_value_prefix(tags)
            value_name = v['name']
            if value_name == 'undefined':
                self.has_undefined = True
            self.values.append({'name': value_name, 'value': value})


class BitmaskType(DawnType):
    """Bitmask type (flags)."""

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        self.values = []

        for v in json_data.get('values', []):
            tags = v.get('tags', [])
            if not _is_enabled(tags):
                continue
            value = v.get('value')
            if value is not None:
                value += _tag_value_prefix(tags)
            self.values.append({'name': v['name'], 'value': value})


class StructType(DawnType):
    """Structure type."""

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        self.members = []
        self.extensible = json_data.get('extensible')  # 'in' or 'out'
        self.chained = json_data.get('chained')  # 'in' or 'out'
        self.out = json_data.get('out', False)

        for m in json_data.get('members', []):
            if _is_enabled(m.get('tags', [])):
                self.members.append({
                    'name': m['name'],
                    'type': m['type'],
                    'annotation': m.get('annotation', ''),
                    'default': m.get('default'),
                })

    def is_chained(self) -> bool:
        return self.chained is not None

    def is_output(self) -> bool:
        """Check if this is an output structure (filled in by the API)."""
        return self.chained == 'out' or self.extensible == 'out' or self.out

    def has_free_members(self) -> bool:
        """Check if this structure needs a FreeMembers function."""
        if not self.is_output():
            return False
        for m in self.members:
            if m['annotation'] != '' or m['type'] == 'string view':
                return True
        return False


class CallbackInfoType(StructType):
    """Callback info structure type.

    These always have:
    - extensible = 'in' (nextInChain)
    - Implicit userdata1 and userdata2 members at the end
    """

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        # Callback info structs are always extensible
        self.extensible = 'in'


class ObjectType(DawnType):
    """Object (opaque handle) type."""

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        self.methods = []

        for m in json_data.get('methods', []):
            if _is_enabled(m.get('tags', [])):
                self.methods.append({
                    'name': m['name'],
                    'returns': m.get('returns'),
                    'args': _parse_args(m.get('args', [])),
                })


class CallbackFunctionType(DawnType):
    """Callback function type.

    These get implicit userdata1 and userdata2 parameters at the end.
    NO @nogc nothrow - allows client code to use GC and throw exceptions.
    """

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        self.args = _parse_args(json_data.get('args', []))


class FunctionPointerType(DawnType):
    """Function pointer type.

    These do NOT get implicit userdata - only the args from the JSON.
    NO @nogc nothrow - allows client code to use GC and throw exceptions.
    """

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        self.returns = json_data.get('returns')
        self.args = _parse_args(json_data.get('args', []))


class FunctionType(DawnType):
    """Standalone function."""

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        self.returns = json_data.get('returns')
        self.args = _parse_args(json_data.get('args', []))


class TypedefType(DawnType):
    """Typedef type alias."""

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        self.aliased_type = json_data.get('type', '')


class ConstantType(DawnType):
    """Constant value."""

    def __init__(self, name: str, json_data: dict, generator: 'DawnGenerator'):
        super().__init__(name, json_data, generator)
        self.value_type = json_data.get('type', 'uint64_t')
        self.value = json_data.get('value', '0')


# =============================================================================
# Generator
# =============================================================================

class DawnGenerator:
    """Main generator class."""

    def __init__(self, json_path: str, output_path: str, module_name: str):
        with open(json_path, 'r') as f:
            json_data = json.load(f, object_pairs_hook=OrderedDict)

        self.types: Dict[str, DawnType] = OrderedDict()
        self.constants: Dict[str, ConstantType] = OrderedDict()
        self.typedefs: Dict[str, TypedefType] = OrderedDict()
        self.type_prefix = json_data.get('_metadata', {}).get('c_prefix', 'WGPU')
        self.module_name = module_name

        self._parse_types(json_data)

    def _parse_types(self, json_data: dict):
        for name, data in json_data.items():
            if name.startswith('_'):
                if name == '_comment':
                    self.copyright = data
                continue
            if not isinstance(data, dict):
                continue

            category = data.get('category', '')

            if category == 'enum':
                t = EnumType(name, data, self)
            elif category == 'bitmask':
                t = BitmaskType(name, data, self)
            elif category == 'structure':
                t = StructType(name, data, self)
            elif category == 'object':
                t = ObjectType(name, data, self)
            elif category == 'callback function':
                t = CallbackFunctionType(name, data, self)
            elif category == 'function pointer':
                t = FunctionPointerType(name, data, self)
            elif category == 'function':
                t = FunctionType(name, data, self)
            elif category == 'callback info':
                t = CallbackInfoType(name, data, self)
            elif category == 'typedef':
                t = TypedefType(name, data, self)
                if t.is_enabled():
                    self.typedefs[name] = t
                continue
            elif category == 'native':
                continue
            elif category == 'constant':
                c = ConstantType(name, data, self)
                if c.is_enabled():
                    self.constants[name] = c
                continue
            else:
                continue

            if t.is_enabled():
                self.types[name] = t

    def resolve_type(self, type_name, annotation: str = '') -> str:
        """Resolve a type name to its D representation."""
        if isinstance(type_name, dict):
            actual_type = type_name.get('type', 'void')
            annotation = type_name.get('annotation', annotation)
            return self.resolve_type(actual_type, annotation)

        if type_name in PRIMITIVE_TYPE_MAP:
            base = PRIMITIVE_TYPE_MAP[type_name]
        elif type_name in self.types:
            base = self.types[type_name].d_type_name()
        elif type_name in self.typedefs:
            base = self.typedefs[type_name].d_type_name()
        else:
            base = self.type_prefix + to_PascalCase(type_name)

        if annotation == 'const*':
            return f'const({base})*'
        elif annotation == '*':
            return f'{base}*'
        elif annotation == 'const*const*':
            return f'const({base}*)*'
        elif annotation == '*const*':
            return f'{base}**'

        return base

    def _get_enum_type(self, type_name: str) -> Optional[EnumType]:
        """Get the EnumType for a type name, or None if not an enum."""
        if type_name in self.types:
            t = self.types[type_name]
            if isinstance(t, EnumType):
                return t
        return None

    def _get_bitmask_type(self, type_name: str) -> Optional[BitmaskType]:
        """Get the BitmaskType for a type name, or None if not a bitmask."""
        if type_name in self.types:
            t = self.types[type_name]
            if isinstance(t, BitmaskType):
                return t
        return None

    def _get_type_category(self, type_name: str) -> str:
        """Get the category of a type."""
        if type_name in PRIMITIVE_TYPE_MAP:
            return 'native'
        if type_name in self.types:
            return self.types[type_name].category
        return 'unknown'

    def default_value(self, type_name: str, default: Any, annotation: str = '') -> Optional[str]:
        """
        Get the D default value for a struct member.

        Follows Dawn's api.h template logic:
        1. Pointers/Objects/Callbacks -> null
        2. Enum with hasUndefined -> ALWAYS .undefined (ignores member's explicit default!)
        3. Enum without undefined + member has default -> use that default
        4. Enum without undefined + no default -> cast(T)0
        5. Bitmask with default -> use that default
        6. Bitmask without default -> .none
        7. Primitives with default -> use that default
        8. Primitives without default -> 0/0.0/false
        """
        # Rule 1: Pointer types always default to null
        if annotation in ('const*', '*', 'const*const*', '*const*'):
            return 'null'

        # Check type category
        category = self._get_type_category(type_name)

        # Objects and callbacks always default to null
        if category == 'object':
            return 'null'
        if category in ('callback function', 'function pointer'):
            return 'null'

        # Enum handling (Rules 2-4)
        enum_type = self._get_enum_type(type_name)
        if enum_type:
            # Rule 2: If enum has undefined, ALWAYS use undefined
            if enum_type.has_undefined:
                return f'{enum_type.d_type_name()}.undefined'
            # Rule 3: If member has explicit default, use it
            if default is not None and default != 'nullptr':
                val_name = d_name(str(default))
                return f'{enum_type.d_type_name()}.{val_name}'
            # Rule 4: No undefined, no default -> cast to 0
            return f'cast({enum_type.d_type_name()})0'

        # Bitmask handling (Rules 5-6)
        bitmask_type = self._get_bitmask_type(type_name)
        if bitmask_type:
            # Rule 5: If member has explicit default, use it
            if default is not None and default != 'nullptr':
                val_name = d_name(str(default))
                return f'{bitmask_type.d_type_name()}.{val_name}'
            # Rule 6: No default -> .none
            return f'{bitmask_type.d_type_name()}.none'

        # Structure handling
        if category == 'structure':
            if default == 'zero':
                # Special "zero" default - need to construct with zeros
                return self._get_struct_zero_init(type_name)
            # Structures without default don't need explicit initialization
            return None

        # Callback info
        if category == 'callback info':
            return None

        # Primitive handling (Rules 7-8)
        if category == 'native' or type_name in PRIMITIVE_TYPE_MAP:
            # Pointer types need null, not 0
            if 'void' in type_name and '*' in type_name:
                return 'null'

            if default is not None:
                if default == 'nullptr':
                    return 'null'
                if isinstance(default, bool):
                    return 'true' if default else 'false'
                if default == 'false':
                    return 'false'
                if default == 'true':
                    return 'true'
                # Check if it's a constant reference
                if isinstance(default, str) and default in self.constants:
                    const_name = f'{self.type_prefix}{to_PascalCase(self.constants[default].json_name)}'
                    return const_name
                # Numeric literal
                if isinstance(default, (int, float)):
                    return str(default)
                if isinstance(default, str):
                    # Handle C float literals
                    if default.endswith('f') or default.endswith('F'):
                        return default[:-1]
                    if default.isdigit() or (default.startswith('-') and default[1:].isdigit()):
                        return default
                    if default.startswith('0x'):
                        return default
                    # Might be a constant name
                    return default
            # Rule 8: No default for primitives
            if type_name in ('float', 'double'):
                return '0.0'
            if type_name == 'bool':
                return 'false'
            return '0'

        return None

    def _get_struct_zero_init(self, type_name: str) -> Optional[str]:
        """
        Generate a struct literal that initializes all enum/bitmask members to their
        "binding not used" or zero values when default="zero" is specified.
        """
        if type_name not in self.types:
            return None
        t = self.types[type_name]
        if not isinstance(t, StructType):
            return None

        assigns = []
        for m in t.members:
            member_type = m['type']
            member_name = d_name(m['name'])
            annotation = m['annotation']

            # Annotated members are pointers; object/callback handles are implicitly pointers
            category = self._get_type_category(member_type)
            if annotation or category in ('object', 'callback function', 'function pointer'):
                assigns.append(f'{member_name}: null')
                continue

            # For zero init, we need to override defaults to their zero/binding-not-used values
            enum_type = self._get_enum_type(member_type)
            if enum_type:
                # Find bindingNotUsed or the 0 value
                zero_val = None
                for v in enum_type.values:
                    if to_camelCase(v['name']) == 'bindingNotUsed':
                        zero_val = 'bindingNotUsed'
                        break
                    if v['value'] == 0:
                        zero_val = d_name(v['name'])
                        break
                if zero_val:
                    assigns.append(f'{member_name}: {enum_type.d_type_name()}.{zero_val}')
                continue

            bitmask_type = self._get_bitmask_type(member_type)
            if bitmask_type:
                assigns.append(f'{member_name}: {bitmask_type.d_type_name()}.none')
                continue

        if not assigns:
            return None

        return '{ ' + ', '.join(assigns) + ' }'

    def _types_of(self, cls, exclude=None) -> list:
        return [t for t in self.types.values()
                if isinstance(t, cls) and (exclude is None or not isinstance(t, exclude))]

    def _get_stype_value(self, struct_name: str) -> Optional[str]:
        return f'{self.type_prefix}SType.{d_name(struct_name)}'

    def _file_header(self, module: str) -> List[str]:
        header = "// Auto-generated from dawn.json - DO NOT EDIT\n\n"
        if self.copyright:
            if isinstance(self.copyright, list):
                header += '\n'.join(f'// {line}' for line in self.copyright) + '\n'
            else:
                header += f'// {self.copyright}\n'

        header += f'module {module};\n'
        return [header]
        

    @staticmethod
    def _section(title: str, content: List[str]) -> List[str]:
        lines = [
            f'// {title}',
            '',
        ]
        lines.extend(content)
        lines.append('')
        return lines

    def generate_types(self) -> str:
        """Generate the types module: constants, built-in types, opaque handles, enums, bitmasks, structs, typedefs."""
        lines = self._file_header(f'{self.module_name}.types')
        lines.append('import core.stdc.stdint;')
        lines.append('')

        lines.extend(self._section('Constants', self._generate_constants()))
        lines.extend(self._section('Built-in Types', self._generate_builtin_types()))

        opaque: List[str] = []
        for t in self._types_of(ObjectType):
            opaque.append(f'struct {t.d_type_name()}Impl;')
            opaque.append(f'alias {t.d_type_name()} = {t.d_type_name()}Impl*;')
        lines.extend(self._section('Opaque Handles', opaque))

        enum_lines: List[str] = []
        for t in self._types_of(EnumType):
            enum_lines.extend(self._generate_enum(t))
            enum_lines.append('')
        lines.extend(self._section('Enums', enum_lines))

        bitmask_lines: List[str] = []
        for t in self._types_of(BitmaskType):
            bitmask_lines.extend(self._generate_bitmask(t))
            bitmask_lines.append('')
        lines.extend(self._section('Bitmasks', bitmask_lines))

        fp_lines: List[str] = []
        for t in self._types_of(FunctionPointerType):
            fp_lines.extend(self._generate_function_pointer(t))
        lines.extend(self._section('Function Pointer Types', fp_lines))

        cb_lines: List[str] = []
        for t in self._types_of(CallbackFunctionType):
            cb_lines.extend(self._generate_callback_function(t))
        lines.extend(self._section('Callback Function Types', cb_lines))

        struct_lines: List[str] = []
        for t in self._types_of(StructType, exclude=CallbackInfoType):
            struct_lines.extend(self._generate_struct(t))
            struct_lines.append('')
        for t in self._types_of(CallbackInfoType):
            struct_lines.extend(self._generate_callback_info_struct(t))
            struct_lines.append('')
        lines.extend(self._section('Structures', struct_lines))

        if self.typedefs:
            typedef_lines: List[str] = []
            for t in self.typedefs.values():
                typedef_lines.extend(self._generate_typedef(t))
            lines.extend(self._section('Typedefs (deprecated aliases)', typedef_lines))

        return '\n'.join(lines)

    def generate_functions(self) -> str:
        """Generate the functions module: extern(C) API declarations."""
        lines = self._file_header(f'{self.module_name}.functions')
        lines.append(f'import {self.module_name}.types;')
        lines.append('import core.stdc.stdint;')
        lines.append('')

        func_lines: List[str] = ['extern(C) @nogc nothrow:', '']
        for t in self._types_of(FunctionType):
            func_lines.extend(self._generate_function(t))
        for t in self._types_of(ObjectType):
            func_lines.extend(self._generate_object_methods(t))
        for t in self._types_of(StructType):
            if t.has_free_members():
                func_lines.extend(self._generate_struct_free_members(t))
        lines.extend(func_lines)

        return '\n'.join(lines)

    def _generate_builtin_types(self) -> List[str]:
        """Generate built-in types that aren't in dawn.json."""
        p = self.type_prefix
        lines = []

        # Bool alias (binary compatible with uint32_t)
        lines.append(f'alias {p}Bool = uint;')
        lines.append('')

        # ChainedStruct
        lines.append(f'struct {p}ChainedStruct')
        lines.append('{')
        lines.append(f'    const({p}ChainedStruct)* next = null;')
        lines.append(f'    {p}SType sType;')
        lines.append('}')
        lines.append('')

        # ChainedStructOut (for output chains)
        lines.append(f'struct {p}ChainedStructOut')
        lines.append('{')
        lines.append(f'    {p}ChainedStructOut* next = null;')
        lines.append(f'    {p}SType sType;')
        lines.append('}')

        return lines

    def _generate_constants(self) -> List[str]:
        """Generate constant declarations."""
        lines = []
        p = self.type_prefix

        for c in self.constants.values():
            d_type = PRIMITIVE_TYPE_MAP.get(c.value_type, 'uint')
            const_name = f'{p}{to_PascalCase(c.json_name)}'

            # Map C macros to D values
            d_value = C_CONSTANT_MAP.get(c.value, c.value)

            lines.append(f'enum {d_type} {const_name} = {d_value};')

        return lines

    def _generate_enum(self, t: EnumType) -> List[str]:
        """Generate an enum definition (non-bitmask)."""
        lines = []
        # Enums use uint base type (NO Force32 needed in D)
        lines.append(f'enum {t.d_type_name()} : uint')
        lines.append('{')

        for v in t.values:
            name = d_name(v['name'])
            if v['value'] is not None:
                lines.append(f"    {name} = 0x{v['value']:08X},")
            else:
                lines.append(f"    {name},")

        lines.append('}')
        return lines

    def _generate_bitmask(self, t: BitmaskType) -> List[str]:
        """Generate a bitmask enum definition."""
        lines = []
        # Bitmasks use ulong base type for full 64-bit flag support
        lines.append(f'enum {t.d_type_name()} : ulong')
        lines.append('{')

        for v in t.values:
            name = d_name(v['name'])
            if v['value'] is not None:
                lines.append(f"    {name} = 0x{v['value']:016X},")
            else:
                lines.append(f"    {name},")

        lines.append('}')
        return lines

    def _generate_function_pointer(self, t: FunctionPointerType) -> List[str]:
        """
        Generate a function pointer type.

        Function pointers do NOT get implicit userdata parameters.
        NO @nogc nothrow - allows client code flexibility.
        """
        lines = []

        # Return type
        if t.returns:
            ret_type = self.resolve_type(t.returns)
        else:
            ret_type = 'void'

        # Arguments - only the explicit ones from JSON
        args = []
        for a in t.args:
            d_type = self.resolve_type(a['type'], a['annotation'])
            arg_name = d_name(a['name'])
            args.append(f'{d_type} {arg_name}')

        arg_str = ', '.join(args) if args else ''
        lines.append(f'alias {t.d_type_name()} = extern(C) {ret_type} function({arg_str});')

        return lines

    def _generate_callback_function(self, t: CallbackFunctionType) -> List[str]:
        """
        Generate a callback function type.

        Callback functions get implicit userdata1 and userdata2 parameters at the end.
        NO @nogc nothrow - allows client code to use GC and throw exceptions.
        """
        lines = []

        # Build argument list from JSON
        args = []
        for a in t.args:
            d_type = self.resolve_type(a['type'], a['annotation'])
            arg_name = d_name(a['name'])
            args.append(f'{d_type} {arg_name}')

        # Add implicit userdata1 and userdata2 parameters (Dawn convention)
        args.append('void* userdata1')
        args.append('void* userdata2')

        arg_str = ', '.join(args)
        lines.append(f'alias {t.d_type_name()} = extern(C) void function({arg_str});')

        return lines

    def _generate_struct(self, t: StructType) -> List[str]:
        """Generate a struct definition."""
        lines = []
        p = self.type_prefix
        lines.append(f'struct {t.d_type_name()}')
        lines.append('{')

        # Add chain member for chained structs (with sType initialization)
        if t.is_chained():
            stype_val = self._get_stype_value(t.json_name)
            if t.chained == 'in':
                lines.append(f'    {p}ChainedStruct chain = {p}ChainedStruct(null, {stype_val});')
            else:
                lines.append(f'    {p}ChainedStructOut chain = {p}ChainedStructOut(null, {stype_val});')

        # Add nextInChain for extensible structs
        if t.extensible:
            if t.extensible == 'in':
                lines.append(f'    const({p}ChainedStruct)* nextInChain = null;')
            else:
                lines.append(f'    {p}ChainedStructOut* nextInChain = null;')

        # Regular members from JSON
        for m in t.members:
            d_type = self.resolve_type(m['type'], m['annotation'])
            member_name = d_name(m['name'])

            default = self.default_value(m['type'], m['default'], m['annotation'])

            if default is not None:
                lines.append(f'    {d_type} {member_name} = {default};')
            else:
                lines.append(f'    {d_type} {member_name};')

        # Add helper methods for StringView
        if t.json_name == 'string view':
            lines.append('')
            lines.append('    /// Construct from D string (no allocation, just a view)')
            lines.append('    this(const(char)[] s) @nogc nothrow pure')
            lines.append('    {')
            lines.append('        data = s.ptr;')
            lines.append('        length = s.length;')
            lines.append('    }')
            lines.append('')
            lines.append('    /// Get as a D slice (no allocation, borrows memory)')
            lines.append('    const(char)[] slice() const @nogc nothrow pure')
            lines.append('    {')
            lines.append('        if (data is null) return null;')
            lines.append('        return data[0 .. length];')
            lines.append('    }')
            lines.append('')
            lines.append('    /// Convert to owned D string (allocates via GC)')
            lines.append('    string toGCString() const')
            lines.append('    {')
            lines.append('        if (data is null || length == 0) return "";')
            lines.append('        return cast(string) data[0 .. length].idup;')
            lines.append('    }')
            lines.append('')
            lines.append('    /// Alias for slice() to work with writeln etc')
            lines.append('    alias toString = slice;')

        lines.append('}')
        return lines

    def _generate_callback_info_struct(self, t: CallbackInfoType) -> List[str]:
        """
        Generate a callback info struct.

        These always have:
        - nextInChain (from extensible='in')
        - Explicit members from JSON
        - Implicit userdata1 and userdata2 at the end
        """
        lines = []
        p = self.type_prefix
        lines.append(f'struct {t.d_type_name()}')
        lines.append('{')

        # nextInChain (callback info structs are always extensible='in')
        lines.append(f'    const({p}ChainedStruct)* nextInChain = null;')

        # Regular members from JSON
        for m in t.members:
            d_type = self.resolve_type(m['type'], m['annotation'])
            member_name = d_name(m['name'])

            default = self.default_value(m['type'], m['default'], m['annotation'])

            if default is not None:
                lines.append(f'    {d_type} {member_name} = {default};')
            else:
                lines.append(f'    {d_type} {member_name};')

        # Implicit userdata1 and userdata2
        lines.append('    void* userdata1 = null;')
        lines.append('    void* userdata2 = null;')

        lines.append('}')
        return lines

    def _generate_typedef(self, t: TypedefType) -> List[str]:
        """Generate a typedef alias."""
        lines = []
        # Get the aliased type's D name
        if t.aliased_type in self.types:
            aliased_d_type = self.types[t.aliased_type].d_type_name()
        else:
            aliased_d_type = self.type_prefix + to_PascalCase(t.aliased_type)

        lines.append(f'// {t.d_type_name()} is deprecated. Use {aliased_d_type} instead.')
        lines.append(f'alias {t.d_type_name()} = {aliased_d_type};')
        lines.append('')
        return lines

    def _generate_function(self, t: FunctionType) -> List[str]:
        """Generate a standalone function declaration."""
        lines = []

        # Return type
        if t.returns:
            ret_type = self.resolve_type(t.returns)
        else:
            ret_type = 'void'

        # Arguments
        args = []
        for a in t.args:
            d_type = self.resolve_type(a['type'], a['annotation'])
            arg_name = d_name(a['name'])
            args.append(f'{d_type} {arg_name}')

        arg_str = ', '.join(args) if args else ''
        func_name = 'wgpu' + to_PascalCase(t.json_name)

        lines.append(f'{ret_type} {func_name}({arg_str});')

        return lines

    def _generate_object_methods(self, t: ObjectType) -> List[str]:
        """Generate method declarations for an object type."""
        lines = []

        obj_type = t.d_type_name()
        base_name = t.base_name()
        param_name = base_name[0].lower() + base_name[1:]

        for m in t.methods:
            # Return type
            if m['returns']:
                ret_type = self.resolve_type(m['returns'])
            else:
                ret_type = 'void'

            # Arguments (object handle is first arg)
            args = [f'{obj_type} {param_name}']
            for a in m['args']:
                d_type = self.resolve_type(a['type'], a['annotation'])
                arg_name = d_name(a['name'])
                args.append(f'{d_type} {arg_name}')

            arg_str = ', '.join(args)
            func_name = 'wgpu' + base_name + to_PascalCase(m['name'])

            lines.append(f'{ret_type} {func_name}({arg_str});')

        # Add implicit AddRef/Release methods
        lines.append(f'void wgpu{base_name}AddRef({obj_type} {param_name});')
        lines.append(f'void wgpu{base_name}Release({obj_type} {param_name});')
        lines.append('')

        return lines

    def _generate_struct_free_members(self, t: StructType) -> List[str]:
        """Generate FreeMembers function for output structs."""
        lines = []

        struct_type = t.d_type_name()
        base_name = t.base_name()
        param_name = base_name[0].lower() + base_name[1:]

        func_name = f'wgpu{base_name}FreeMembers'
        lines.append(f'void {func_name}({struct_type} {param_name});')

        return lines


def main():
    import os
    generator = DawnGenerator("dawn/dawn.json", "source/dawned", "dawned")

    files = {
        'source/dawned/types.d': generator.generate_types(),
        'source/dawned/functions.d': generator.generate_functions(),
    }
    for path, content in files.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(content)
        print(f'Generated {path}')


if __name__ == '__main__':
    main()
