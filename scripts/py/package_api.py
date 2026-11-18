#!/usr/bin/env python3
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLASSES_DIR = ROOT / 'force-app' / 'classes'
OUTPUT_FILE = ROOT / 'docs' / 'documentation' / 'package_api.apex'


class ApexEntity:
    def __init__(self, name: str, kind: str, is_global: bool = False, parent: str | None = None, decl_suffix: str | None = None):
        self.name = name
        self.kind = kind  # 'class' or 'interface'
        self.is_global = is_global
        self.parent = parent
        self.decl_suffix = decl_suffix or ""
        self.decl_prefix = ""
        self.extends: str | None = None
        self.implements: list[str] = []
        self.methods: list[str] = []
        self.nested: list['ApexEntity'] = []
        self.enum_constants: list[str] = []

    def add_method(self, signature: str):
        # Clean up spaces around parentheses
        sig = re.sub(r'\(\s+', '(', signature)  # Remove space after (
        sig = re.sub(r'\s+\)', ')', sig)        # Remove space before )
        self.methods.append(sig)
    
    def is_extensible(self) -> bool:
        """Check if this class is extensible (abstract or virtual)"""
        return 'abstract' in self.decl_prefix or 'virtual' in self.decl_prefix


GLOBAL_CLASS_RE = re.compile(r"^\s*global\s+(?P<prefix>.*?)\bclass\s+(?P<name>[A-Za-z0-9_]+)(?P<suffix>[^\{]*)\{", re.MULTILINE)
GLOBAL_INTERFACE_RE = re.compile(r"^\s*global\s+(?P<prefix>.*?)\binterface\s+(?P<name>[A-Za-z0-9_]+)(?P<suffix>[^\{]*)\{", re.MULTILINE)
GLOBAL_ENUM_RE = re.compile(r"^\s*global\s+enum\s+([A-Za-z0-9_]+)\s*\{", re.MULTILINE)
# Non-global patterns (for building complete inheritance map)
CLASS_RE = re.compile(r"^\s*(?P<access>public|private|protected|global)\s+(?P<prefix>.*?)\bclass\s+(?P<name>[A-Za-z0-9_]+)(?P<suffix>[^\{]*)\{", re.MULTILINE)
INTERFACE_RE = re.compile(r"^\s*(?P<access>public|private|protected|global)\s+(?P<prefix>.*?)\binterface\s+(?P<name>[A-Za-z0-9_]+)(?P<suffix>[^\{]*)\{", re.MULTILINE)


def find_matching_brace(text: str, start_idx: int) -> int:
    depth = 0
    for i in range(start_idx, len(text)):
        c = text[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
    return -1


def parse_inheritance(suffix: str) -> tuple[str | None, list[str]]:
    """
    Parse extends/implements from class/interface suffix.
    Returns (extends_class, [implements_interfaces])
    """
    suffix = suffix.strip()
    extends_class = None
    implements_list = []
    
    # Parse 'extends ClassName'
    extends_match = re.search(r'\bextends\s+([A-Za-z0-9_\.]+)', suffix)
    if extends_match:
        extends_class = extends_match.group(1)
    
    # Parse 'implements Interface1, Interface2, ...'
    implements_match = re.search(r'\bimplements\s+([A-Za-z0-9_\.,\s]+)', suffix)
    if implements_match:
        interfaces_str = implements_match.group(1)
        implements_list = [i.strip() for i in interfaces_str.split(',') if i.strip()]
    
    return extends_class, implements_list


def extract_entities_from_text(text: str, parent: str | None = None, global_only: bool = False) -> list[ApexEntity]:
    """
    Extract apex entities from text.
    
    Args:
        text: The source code text
        parent: Parent entity name (for nested entities)
        global_only: If True, only extract global entities. If False, extract all entities.
    
    Returns:
        List of ApexEntity objects
    """
    entities: list[ApexEntity] = []
    
    # Choose which patterns to use based on global_only flag
    if global_only:
        patterns = [(GLOBAL_CLASS_RE, 'class'), (GLOBAL_INTERFACE_RE, 'interface')]
    else:
        patterns = [(CLASS_RE, 'class'), (INTERFACE_RE, 'interface')]
    
    for matcher, kind in patterns:
        for m in matcher.finditer(text):
            name = m.group('name')
            
            # Determine if global (access modifier check for non-global patterns)
            if 'access' in m.groupdict():
                is_global = m.group('access') == 'global'
            else:
                is_global = True  # GLOBAL_CLASS_RE/GLOBAL_INTERFACE_RE matches
            
            prefix_raw = (m.group('prefix') or "").strip()
            suffix_raw = (m.group('suffix') or "").strip()
            decl_suffix = re.sub(r"\s+", " ", suffix_raw)
            decl_prefix = re.sub(r"\s+", " ", prefix_raw)
            
            body_start = text.find('{', m.end() - 1)
            if body_start == -1:
                continue
            body_end = find_matching_brace(text, body_start)
            if body_end == -1:
                continue
            body = text[body_start + 1: body_end]

            # Create entity
            entity = ApexEntity(name, kind, is_global, parent, decl_suffix)
            entity.decl_prefix = decl_prefix
            
            # Parse inheritance
            extends_class, implements_list = parse_inheritance(suffix_raw)
            entity.extends = extends_class
            entity.implements = implements_list
            
            # Check if this is an abstract or virtual class (extensibility contract)
            is_extensible = 'abstract' in decl_prefix or 'virtual' in decl_prefix

            # First, identify all nested entity boundaries (classes, interfaces, enums)
            nested_ranges: list[tuple[int, int]] = []
            
            # For nested entities, always look for ALL entities (not just global)
            # because we need to exclude them from method scanning
            for nested_pattern in [CLASS_RE, INTERFACE_RE]:
                for nested_m in nested_pattern.finditer(body):
                    nested_body_start = body.find('{', nested_m.end() - 1)
                    if nested_body_start != -1:
                        nested_body_end = find_matching_brace(body, nested_body_start)
                        if nested_body_end != -1:
                            # Range from start of declaration to end of body
                            nested_ranges.append((nested_m.start(), nested_body_end + 1))
            
            # Find nested enums (both global and non-global)
            for nested_m in re.finditer(r"^\s*(?:global|public|private|protected)\s+enum\s+[A-Za-z0-9_]+\s*\{", body, re.MULTILINE):
                nested_body_start = body.find('{', nested_m.end() - 1)
                if nested_body_start != -1:
                    nested_body_end = find_matching_brace(body, nested_body_start)
                    if nested_body_end != -1:
                        nested_ranges.append((nested_m.start(), nested_body_end + 1))

            def is_in_nested_entity(char_pos: int) -> bool:
                """Check if a character position is within a nested entity"""
                for start, end in nested_ranges:
                    if start <= char_pos < end:
                        return True
                return False

            # Methods and properties directly within this entity
            body_lines = body.splitlines()
            char_pos = 0
            for i, line in enumerate(body_lines):
                stripped = line.strip()
                line_start_pos = char_pos
                char_pos += len(line) + 1  # +1 for newline
                
                # Skip lines that are within nested entities
                if is_in_nested_entity(line_start_pos):
                    continue
                
                if kind == 'class':
                    # For classes, ONLY capture 'global' members (protected is not visible across packages)
                    is_global_member = stripped.startswith('global ')
                    
                    if not is_global_member:
                        continue
                    
                    # Strip the 'global' keyword
                    head_prefix = 'global '
                    access_prefix_to_keep = ''
                    
                    # Methods or field declarations with parentheses
                    if '(' in stripped and ')' in stripped:
                        head = stripped[len(head_prefix):]
                        # Check if this is a field declaration (has '=' before any '(')
                        if '=' in head and head.index('=') < head.index('('):
                            # Field declaration - strip everything from '='
                            head = head.split('=')[0].rstrip(';').strip()
                            sig = re.sub(r"\s+", " ", head).strip()
                            entity.add_method(access_prefix_to_keep + sig + ';')
                        else:
                            # Method - capture up to first ')' inclusive
                            upto = head.split(')')[0] + ')'
                            sig = re.sub(r"\s+", " ", upto).strip()
                            entity.add_method(access_prefix_to_keep + sig + ';')
                    # Handle multiline method signatures (opening paren without closing)
                    elif '(' in stripped and ')' not in stripped:
                        # Start of multiline - could be method or field declaration
                        method_lines = [stripped[len(head_prefix):]]
                        for j in range(i + 1, len(body_lines)):
                            next_line = body_lines[j].strip()
                            # Remove inline comments
                            if '//' in next_line:
                                next_line = next_line.split('//', 1)[0].strip()
                            if not next_line:
                                continue
                            if next_line.startswith('/*') or next_line.startswith('*') or next_line.startswith('*/'):
                                continue
                            method_lines.append(next_line)
                            # Check if this line completes the signature (has closing paren or semicolon)
                            if ')' in next_line or ';' in next_line:
                                # Complete multiline signature found
                                sig = re.sub(r"\s+", " ", ' '.join(method_lines)).strip()
                                # Remove any trailing { if present
                                if sig.endswith('{'):
                                    sig = sig[:-1].strip()
                                # Strip everything after '=' for field initializations
                                if '=' in sig:
                                    sig = sig.split('=')[0].strip()
                                # Ensure it ends with semicolon
                                if not sig.endswith(';'):
                                    sig = sig + ';'
                                entity.add_method(access_prefix_to_keep + sig)
                                break
                    # One-line properties/members with accessor block or semicolon
                    elif '{' in stripped and '}' in stripped:
                        head = stripped[len(head_prefix):]
                        # keep everything between start and first '{' and the accessor block
                        before_brace, _, after = head.partition('{')
                        accessor = after.rsplit('}', 1)[0]
                        before_brace = re.sub(r"\s+", " ", before_brace).strip()
                        accessor = re.sub(r"\s+", " ", accessor).strip()
                        if before_brace and accessor:
                            entity.add_method(access_prefix_to_keep + f"{before_brace} {{ {accessor} }}")
                    elif stripped.endswith(';'):
                        head = stripped[len(head_prefix):].rstrip(';')
                        # Strip everything after '=' (field initializations)
                        if '=' in head:
                            head = head.split('=')[0]
                        head = re.sub(r"\s+", " ", head).strip()
                        if head:
                            entity.add_method(access_prefix_to_keep + head + ';')
                elif kind == 'interface':
                    # Remove inline comments
                    if '//' in stripped:
                        stripped = stripped.split('//', 1)[0].strip()
                    if not stripped:
                        continue
                    if stripped.startswith('/*') or stripped.startswith('*') or stripped.startswith('*/'):
                        continue
                    # Interface method signature: has () and ends with ; and no braces
                    if '(' in stripped and ')' in stripped and stripped.endswith(';') and '{' not in stripped and '}' not in stripped:
                        sig = re.sub(r"\s+", " ", stripped).strip()
                        entity.add_method(sig)
                    # Handle multiline method signatures
                    elif '(' in stripped and not ')' in stripped and not stripped.endswith(';'):
                        # Start of multiline method - collect until we find the closing )
                        method_lines = [stripped]
                        for j in range(i + 1, len(body_lines)):
                            next_line = body_lines[j].strip()
                            # Remove inline comments
                            if '//' in next_line:
                                next_line = next_line.split('//', 1)[0].strip()
                            if not next_line:
                                continue
                            if next_line.startswith('/*') or next_line.startswith('*') or next_line.startswith('*/'):
                                continue
                            method_lines.append(next_line)
                            # Check if this line completes the method signature
                            if ')' in next_line and next_line.endswith(';') and '{' not in next_line and '}' not in next_line:
                                # Complete multiline method signature found
                                sig = re.sub(r"\s+", " ", ' '.join(method_lines)).strip()
                                entity.add_method(sig)
                                break

            # Recurse for nested entities (use same global_only flag)
            entity.nested.extend(extract_entities_from_text(body, parent=name, global_only=global_only))

            # Capture nested GLOBAL enums as members (only if we care about global entities)
            if global_only:
                enum_pattern = GLOBAL_ENUM_RE
            else:
                enum_pattern = re.compile(r"^\s*(?:global|public|private|protected)\s+enum\s+([A-Za-z0-9_]+)\s*\{", re.MULTILINE)
            
            for em in enum_pattern.finditer(body):
                enum_name = em.group(1)
                
                # Determine if this enum is global
                enum_match_text = em.group(0)
                enum_is_global = 'global' in enum_match_text
                
                enum_body_start = body.find('{', em.end() - 1)
                if enum_body_start == -1:
                    continue
                enum_body_end = find_matching_brace(body, enum_body_start)
                if enum_body_end == -1:
                    continue
                enum_body = body[enum_body_start + 1: enum_body_end]
                # Remove line comments and whitespace
                cleaned = []
                for ln in enum_body.splitlines():
                    ln = ln.split('//', 1)[0].strip()
                    if ln:
                        cleaned.append(ln)
                joined = ' '.join(cleaned)
                # Extract constants between braces, split by commas
                constants = [c.strip() for c in joined.split(',') if c.strip()]
                enum_entity = ApexEntity(enum_name, 'enum', enum_is_global, parent=name)
                enum_entity.enum_constants = constants
                entity.nested.append(enum_entity)
            entities.append(entity)
    return entities


def extract_from_file(path: Path, global_only: bool = False) -> list[ApexEntity]:
    try:
        text = path.read_text(encoding='utf-8')
    except Exception:
        return []
    return extract_entities_from_text(text, global_only=global_only)


def collect_all_entities(global_only: bool = False) -> list[ApexEntity]:
    """
    Collect entities from all Apex files.
    
    Args:
        global_only: If True, only collect global entities. If False, collect all entities.
    
    Returns:
        List of top-level ApexEntity objects
    """
    all_entities: list[ApexEntity] = []
    for root, _, files in os.walk(CLASSES_DIR):
        for fn in files:
            if not fn.endswith('.cls'):
                continue
            all_entities.extend(extract_from_file(Path(root) / fn, global_only=global_only))
    # Remove top-level duplicates that are actually nested classes (by name)
    nested_names = {n.name for e in all_entities for n in e.nested}
    filtered = [e for e in all_entities if not (e.parent is None and e.name in nested_names)]
    return filtered


def build_entity_map(entities: list[ApexEntity]) -> dict[str, ApexEntity]:
    """Build a map from entity name to entity for quick lookup"""
    entity_map: dict[str, ApexEntity] = {}
    
    def add_to_map(e: ApexEntity):
        entity_map[e.name] = e
        for nested in e.nested:
            add_to_map(nested)
    
    for e in entities:
        add_to_map(e)
    
    return entity_map


def collect_global_interfaces(entity: ApexEntity, entity_map: dict[str, ApexEntity]) -> set[str]:
    """
    Collect all global interfaces from the inheritance chain.
    Traverses extends/implements recursively.
    """
    global_interfaces: set[str] = set()
    
    # Add directly implemented interfaces that are global
    for iface in entity.implements:
        if iface in entity_map and entity_map[iface].is_global:
            global_interfaces.add(iface)
        # Also traverse interface inheritance
        if iface in entity_map:
            global_interfaces.update(collect_global_interfaces(entity_map[iface], entity_map))
    
    # Traverse parent class
    if entity.extends and entity.extends in entity_map:
        parent = entity_map[entity.extends]
        global_interfaces.update(collect_global_interfaces(parent, entity_map))
    
    return global_interfaces


def normalize_method_signature(method: str) -> str:
    """
    Normalize a method signature for comparison by removing modifiers like 'override', 'virtual',
    and access modifiers like 'protected', 'global', 'public'.
    
    This allows us to detect if two methods are the same, regardless of their modifiers.
    """
    sig = method
    # Remove common modifiers (order matters - remove compound phrases first)
    for modifier in ['protected virtual override', 'protected virtual', 'protected override', 
                     'global virtual override', 'global virtual', 'global override',
                     'public virtual override', 'public virtual', 'public override',
                     'virtual override', 'protected', 'global', 'public', 'virtual', 'override']:
        sig = sig.replace(modifier + ' ', '')
    return sig.strip()


def collect_inherited_methods(entity: ApexEntity, entity_map: dict[str, ApexEntity], existing_signatures: set[str] | None = None) -> list[str]:
    """
    For extensible (abstract/virtual) global classes, collect ONLY global methods
    from the entire non-global inheritance chain.
    
    IMPORTANT: Protected methods are NOT visible across package boundaries, so we only
    collect global methods. This ensures the documentation accurately reflects what
    subscribers can actually access.
    
    Only includes methods that are NOT already present in the entity's own methods
    (to avoid duplication when child overrides parent methods).
    """
    inherited_methods: list[str] = []
    
    # Only collect from parent if entity is extensible
    if not entity.is_extensible():
        return inherited_methods
    
    # Build a set of normalized signatures that already exist in this entity (first call only)
    if existing_signatures is None:
        existing_signatures = {normalize_method_signature(m) for m in entity.methods}
    
    # Traverse up the parent chain
    if entity.extends and entity.extends in entity_map:
        parent = entity_map[entity.extends]
        
        # If parent is non-global, collect ONLY its global methods (not protected)
        if not parent.is_global:
            for method in parent.methods:
                # Only collect global methods (protected is not visible across packages)
                if method.startswith('global '):
                    # Only add if this method signature doesn't already exist
                    normalized_sig = normalize_method_signature(method)
                    if normalized_sig not in existing_signatures:
                        inherited_methods.append(method)
                        # Track that we've added this signature to avoid duplicates from grandparents
                        existing_signatures.add(normalized_sig)
            
            # Recursively collect from grandparents (pass the same existing_signatures set)
            inherited_methods.extend(collect_inherited_methods(parent, entity_map, existing_signatures))
    
    return inherited_methods


def resolve_inheritance(entity: ApexEntity, entity_map: dict[str, ApexEntity]) -> tuple[str, list[str]]:
    """
    Resolve the inheritance for a global entity to show only global parts.
    
    Returns:
        (extends_clause, implements_list) where:
        - extends_clause is the nearest global parent class (or empty string)
        - implements_list contains all global interfaces from the chain
    """
    extends_clause = ""
    global_interfaces: set[str] = set()
    
    # Collect all global interfaces from the chain
    global_interfaces = collect_global_interfaces(entity, entity_map)
    
    # Find the nearest global parent class
    if entity.extends:
        if entity.extends not in entity_map:
            # External type (like Exception, SObject, etc.) - preserve as-is
            extends_clause = entity.extends
        else:
            parent = entity_map[entity.extends]
            if parent.is_global:
                extends_clause = entity.extends
            else:
                # Parent is non-global, traverse up to find global ancestor
                ancestor_extends, _ = resolve_inheritance(parent, entity_map)
                extends_clause = ancestor_extends
    
    return extends_clause, sorted(global_interfaces)


def format_entity(entity: ApexEntity, entity_map: dict[str, ApexEntity] | None = None, indent: str = "") -> list[str]:
    """
    Format an entity for output.
    
    Args:
        entity: The entity to format
        entity_map: Map of all entities (for resolving inheritance). If None, use original suffix.
        indent: Current indentation level
    
    Returns:
        List of formatted lines
    """
    lines: list[str] = []
    kind = entity.kind if entity.kind in ("class", "interface", "enum") else "class"
    prefix = f"{entity.decl_prefix} " if getattr(entity, 'decl_prefix', '') else ""
    
    # Build suffix with resolved inheritance (if entity_map provided)
    if entity_map and entity.is_global and (entity.extends or entity.implements):
        extends_clause, implements_list = resolve_inheritance(entity, entity_map)
        
        suffix_parts = []
        if extends_clause:
            suffix_parts.append(f"extends {extends_clause}")
        if implements_list:
            suffix_parts.append(f"implements {', '.join(implements_list)}")
        
        suffix = f" {' '.join(suffix_parts)}" if suffix_parts else ""
    else:
        suffix = f" {entity.decl_suffix}" if entity.decl_suffix else ""
    
    header = f"{prefix}{kind} {entity.name}{suffix} {{"
    lines.append(indent + header)
    inner_indent = indent + "  "
    
    if kind == 'enum':
        if getattr(entity, 'enum_constants', None):
            lines.append(inner_indent + ', '.join(entity.enum_constants) + ';')
    else:
        # Collect methods (including inherited ones for extensible classes)
        methods = list(entity.methods)
        
        if entity_map and entity.is_global and entity.is_extensible():
            inherited = collect_inherited_methods(entity, entity_map)
            # Add inherited methods that aren't already present
            for method in inherited:
                if method not in methods:
                    methods.append(method)
        
        # Output methods, stripping 'override' keyword (internal implementation detail)
        for m in methods:
            # Remove 'override' keyword - subscribers don't care about internal overrides
            cleaned = m.replace(' override ', ' ').replace('override ', '')
            # Clean up any double spaces created by removal
            cleaned = re.sub(r'\s+', ' ', cleaned)
            lines.append(inner_indent + cleaned)
    
    # Format nested entities (only global ones if we're filtering)
    for nested in entity.nested:
        if nested.is_global:  # Only include global nested entities
            lines.extend(format_entity(nested, entity_map, inner_indent))
    
    lines.append(indent + "}")
    return lines


def generate_output(all_entities: list[ApexEntity], package_api: list[ApexEntity]) -> str:
    """
    Generate the output documentation.
    
    Args:
        all_entities: ALL entities (global and non-global) for inheritance resolution
        package_api: Only global entities to be included in output
    
    Returns:
        The formatted output string
    """
    lines: list[str] = []
    lines.append("// Auto-generated summary of global classes and their global methods.")
    lines.append("// Do not edit manually; regenerate by running scripts/py/package_api.py")
    lines.append("")
    
    # Build complete entity map from ALL entities (for inheritance resolution)
    entity_map = build_entity_map(all_entities)
    
    # Filter to top-level global entities only
    top_level = [e for e in package_api if e.parent is None and e.is_global]

    # Order entities by inheritance depth (interfaces first, then classes)
    def order_bucket(kind: str) -> list[ApexEntity]:
        bucket = {e.name: e for e in top_level if e.kind == kind}
        # Build children map
        children: dict[str, list[str]] = {}
        for name, ent in bucket.items():
            base = ent.extends
            if base and base in bucket:
                children.setdefault(base, []).append(name)
        # Roots: those without a base in bucket
        roots = [name for name in bucket.keys() if not bucket[name].extends or bucket[name].extends not in bucket]
        roots.sort()
        # DFS preorder: root then its subtree
        ordered_names: list[str] = []
        seen: set[str] = set()

        def dfs(n: str):
            if n in seen:
                return
            seen.add(n)
            ordered_names.append(n)
            for child in sorted(children.get(n, [])):
                dfs(child)

        for r in roots:
            dfs(r)
        # Add any disconnected cycles or missed nodes
        for n in sorted(bucket.keys()):
            if n not in seen:
                dfs(n)
        return [bucket[n] for n in ordered_names]

    interfaces = order_bucket('interface')
    classes = order_bucket('class')

    ordered = interfaces + classes

    first = True
    for e in ordered:
        block = format_entity(e, entity_map)
        if not block:
            continue
        if not first and lines and lines[-1] != "":
            lines.append("")
        lines.extend(block)
        first = False
    return "\n".join(lines).rstrip() + "\n"


def main():
    # Phase 1: Collect ALL entities (global and non-global) to build complete inheritance map
    print("Collecting all entities...")
    all_entities = collect_all_entities(global_only=False)
    
    # Phase 2: Collect only global entities for output
    print("Collecting global entities...")
    package_api = collect_all_entities(global_only=True)
    
    # Phase 3: Generate output with resolved inheritance
    print("Generating output with resolved inheritance...")
    content = generate_output(all_entities, package_api)
    
    OUTPUT_FILE.write_text(content, encoding='utf-8')
    print(f"Wrote {OUTPUT_FILE}")


if __name__ == '__main__':
    main()
