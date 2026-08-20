///|
/// Abstract kinds a tracked shell variable may have during CFG analysis.
pub enum VariableKind {
  Unset
  String
  Array
  Integer
} derive(Eq, Hash, Debug)

///|
/// A concrete set of shell variable properties observed during analysis.
pub struct VariablePropertySet {
  exported : Bool
  array_ : Bool
  associative : Bool
  integer : Bool
} derive(Eq, Hash, Debug)

///|
/// Whether a tracked string is empty, clean, or may contain spaces.
pub enum SpaceStatus {
  Empty
  Clean
  Dirty
} derive(Eq, Compare, Debug)

///|
/// Whether a tracked value is known to behave numerically.
pub enum NumericalStatus {
  Unknown
  Empty
  Maybe
  Definitely
} derive(Eq, Compare, Debug)

///|
/// The abstract value tracked for one shell variable.
pub struct VariableValue {
  literal_value : String?
  possible_kinds : Set[VariableKind]
  space_status : SpaceStatus
  numerical_status : NumericalStatus
} derive(Eq)

///|
/// The full tracked state for one shell variable.
pub struct VariableState {
  variable_value : VariableValue
  variable_properties : Set[VariablePropertySet]
} derive(Eq)

///|
/// A snapshot of the abstract program state at one CFG boundary.
pub struct ProgramState {
  variables_in_scope : Map[String, VariableState]
  exit_codes : Set[CfgAstId]
  state_is_reachable : Bool
} derive(Eq)

///|
/// Dataflow results derived from a `CFG`.
pub struct CfgAnalysis {
  priv cfg : CFG
  priv live_node_states : Array[(ProgramState, ProgramState)?]
  priv node_states : Array[(ProgramState, ProgramState)?]
} derive(Eq)

///|
priv enum FunctionTarget {
  Unknown
  Definition(String, CfgNodeId, CfgNodeId)
} derive(Eq, Hash)

///|
priv struct InternalState {
  global_values : Map[String, VariableState]
  local_values : Map[String, VariableState]
  prefix_values : Map[String, VariableState]
  function_targets : Map[String, Set[FunctionTarget]]
  exit_codes : Set[CfgAstId]
  reachable : Bool
} derive(Eq)

///|
priv struct InvocationResult {
  entry : CfgNodeId
  input : InternalState
  states : Array[(InternalState, InternalState)?]
  exit_state : InternalState
}

///|
priv struct PendingStraggler {
  input : InternalState
  target : FunctionTarget
}

///|
priv struct AnalysisContext {
  cfg : CFG
  flow_predecessors : Array[Array[CfgNodeId]]
  successors : Array[Array[CfgNodeId]]
  cache : Ref[Map[CfgNodeId, Array[InvocationResult]]]
  invocations : Ref[Array[InvocationResult]]
  invoked_functions : Ref[Set[CfgNodeId]]
}

///|
fn[A : Hash + Eq] singleton_set(value : A) -> Set[A] {
  let result : Set[A] = Set([])
  result.add(value)
  result
}

///|
fn[A : Hash + Eq] union_set(lhs : Set[A], rhs : Set[A]) -> Set[A] {
  let result = lhs.copy()
  for value in rhs {
    result.add(value)
  }
  result
}

///|
// CHECK THIS: THUNK
fn empty_property_set() -> VariablePropertySet {
  { exported: false, array_: false, associative: false, integer: false }
}

///|
fn default_properties() -> Set[VariablePropertySet] {
  singleton_set(empty_property_set())
}

///|
fn value_with_kind(
  kind : VariableKind,
  literal_value : String?,
  space_status : SpaceStatus,
  numerical_status : NumericalStatus,
) -> VariableValue {
  {
    literal_value,
    possible_kinds: singleton_set(kind),
    space_status,
    numerical_status,
  }
}

///|
fn unknown_variable_value() -> VariableValue {
  value_with_kind(String, None, Dirty, Unknown)
}

///|
fn empty_string_value() -> VariableValue {
  value_with_kind(String, Some(""), Empty, Empty)
}

///|
fn unset_variable_value() -> VariableValue {
  value_with_kind(Unset, Some(""), Empty, Empty)
}

///|
fn array_variable_value() -> VariableValue {
  value_with_kind(Array, None, Dirty, Unknown)
}

///|
fn unknown_integer_value() -> VariableValue {
  value_with_kind(Integer, None, Clean, Definitely)
}

///|
fn unknown_variable_state() -> VariableState {
  {
    variable_value: unknown_variable_value(),
    variable_properties: default_properties(),
  }
}

///|
fn unset_variable_state() -> VariableState {
  {
    variable_value: unset_variable_value(),
    variable_properties: default_properties(),
  }
}

///|
fn array_variable_state() -> VariableState {
  {
    variable_value: array_variable_value(),
    variable_properties: singleton_set({ ..empty_property_set(), array_: true }),
  }
}

///|
fn integer_variable_state() -> VariableState {
  {
    variable_value: unknown_integer_value(),
    variable_properties: default_properties(),
  }
}

///|
fn empty_internal_state() -> InternalState {
  {
    global_values: Map([]),
    local_values: Map([]),
    prefix_values: Map([]),
    function_targets: Map([]),
    exit_codes: Set([]),
    reachable: true,
  }
}

///|
fn unreachable_internal_state() -> InternalState {
  { ..empty_internal_state(), reachable: false }
}

///|
fn unknown_function_targets() -> Set[FunctionTarget] {
  singleton_set(Unknown)
}

///|
fn property_set_add(
  props : VariablePropertySet,
  prop : CfgVariableProp,
) -> VariablePropertySet {
  match prop {
    Export => { ..props, exported: true }
    Array => { ..props, array_: true }
    Associative => { ..props, associative: true }
    Integer => { ..props, integer: true }
  }
}

///|
fn property_set_remove(
  props : VariablePropertySet,
  prop : CfgVariableProp,
) -> VariablePropertySet {
  match prop {
    Export => { ..props, exported: false }
    Array => { ..props, array_: false }
    Associative => { ..props, associative: false }
    Integer => { ..props, integer: false }
  }
}

///|
fn add_properties_to_sets(
  property_sets : Set[VariablePropertySet],
  props : Array[CfgVariableProp],
) -> Set[VariablePropertySet] {
  let result : Set[VariablePropertySet] = Set([])
  if property_sets.is_empty() {
    let mut current = empty_property_set()
    for prop in props {
      current = property_set_add(current, prop)
    }
    result.add(current)
    return result
  }
  for current0 in property_sets {
    let mut current = current0
    for prop in props {
      current = property_set_add(current, prop)
    }
    result.add(current)
  }
  result
}

///|
fn remove_properties_from_sets(
  property_sets : Set[VariablePropertySet],
  props : Array[CfgVariableProp],
) -> Set[VariablePropertySet] {
  let result : Set[VariablePropertySet] = Set([])
  if property_sets.is_empty() {
    result.add(empty_property_set())
    return result
  }
  for current0 in property_sets {
    let mut current = current0
    for prop in props {
      current = property_set_remove(current, prop)
    }
    result.add(current)
  }
  result
}

///|
fn property_sets_have_integer(property_sets : Set[VariablePropertySet]) -> Bool {
  for props in property_sets {
    if props.integer {
      return true
    }
  }
  false
}

///|
fn all_property_sets_have_integer(
  property_sets : Set[VariablePropertySet],
) -> Bool {
  if property_sets.is_empty() {
    return false
  }
  for props in property_sets {
    if !props.integer {
      return false
    }
  }
  true
}

///|
fn property_sets_have_array(property_sets : Set[VariablePropertySet]) -> Bool {
  for props in property_sets {
    if props.array_ || props.associative {
      return true
    }
  }
  false
}

///|
fn ensure_possible_kind(
  value : VariableValue,
  kind : VariableKind,
) -> VariableValue {
  {
    ..value,
    possible_kinds: union_set(value.possible_kinds, singleton_set(kind)),
  }
}

///|
fn kind_is_possible(value : VariableValue, kind : VariableKind) -> Bool {
  value.possible_kinds.contains(kind)
}

///|
fn add_properties_to_state(
  state : VariableState,
  props : Array[CfgVariableProp],
) -> VariableState {
  let mut next_value = state.variable_value
  if contains_prop(props, Array) || contains_prop(props, Associative) {
    next_value = ensure_possible_kind(next_value, Array)
  }
  {
    variable_value: next_value,
    variable_properties: add_properties_to_sets(
      state.variable_properties,
      props,
    ),
  }
}

///|
fn remove_properties_from_state(
  state : VariableState,
  props : Array[CfgVariableProp],
) -> VariableState {
  {
    variable_value: state.variable_value,
    variable_properties: remove_properties_from_sets(
      state.variable_properties,
      props,
    ),
  }
}

///|
fn contains_prop(
  values : Array[CfgVariableProp],
  target : CfgVariableProp,
) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn merge_space_status(lhs : SpaceStatus, rhs : SpaceStatus) -> SpaceStatus {
  match (lhs, rhs) {
    (Empty, other) => other
    (other, Empty) => other
    (Clean, Clean) => Clean
    _ => Dirty
  }
}

///|
fn merge_numerical_status(
  lhs : NumericalStatus,
  rhs : NumericalStatus,
) -> NumericalStatus {
  match (lhs, rhs) {
    (Definitely, Definitely) => Definitely
    (Definitely, _) | (_, Definitely) => Maybe
    (Maybe, _) | (_, Maybe) => Maybe
    (Empty, Empty) => Empty
    _ => Unknown
  }
}

///|
fn append_space_status(lhs : SpaceStatus, rhs : SpaceStatus) -> SpaceStatus {
  match (lhs, rhs) {
    (Empty, other) => other
    (other, Empty) => other
    (Clean, Clean) => Clean
    _ => Dirty
  }
}

///|
fn append_numerical_status(
  lhs : NumericalStatus,
  rhs : NumericalStatus,
) -> NumericalStatus {
  match (lhs, rhs) {
    (Empty, other) => other
    (other, Empty) => other
    (Definitely, Definitely) => Definitely
    (Unknown, _) | (_, Unknown) => Unknown
    _ => Maybe
  }
}

///|
fn merge_variable_value(
  lhs : VariableValue,
  rhs : VariableValue,
) -> VariableValue {
  {
    literal_value: if lhs.literal_value == rhs.literal_value {
      lhs.literal_value
    } else {
      None
    },
    possible_kinds: union_set(lhs.possible_kinds, rhs.possible_kinds),
    space_status: merge_space_status(lhs.space_status, rhs.space_status),
    numerical_status: merge_numerical_status(
      lhs.numerical_status,
      rhs.numerical_status,
    ),
  }
}

///|
fn merge_variable_state(
  lhs : VariableState,
  rhs : VariableState,
) -> VariableState {
  {
    variable_value: merge_variable_value(lhs.variable_value, rhs.variable_value),
    variable_properties: union_set(
      lhs.variable_properties,
      rhs.variable_properties,
    ),
  }
}

///|
fn append_variable_value(
  lhs : VariableValue,
  rhs : VariableValue,
) -> VariableValue {
  {
    literal_value: match (lhs.literal_value, rhs.literal_value) {
      (Some(left), Some(right)) => Some(left + right)
      _ => None
    },
    possible_kinds: singleton_set(String),
    space_status: append_space_status(lhs.space_status, rhs.space_status),
    numerical_status: append_numerical_status(
      lhs.numerical_status,
      rhs.numerical_status,
    ),
  }
}

///|
fn create_environment_state() -> InternalState {
  let mut state = empty_internal_state()
  for name in @semantics.internal_variable_names() {
    state = set_global_value(state, name, unknown_variable_state())
  }
  for name in @semantics.variable_names_without_spaces() {
    state = set_global_value(state, name, {
      variable_value: { ..unknown_variable_value(), space_status: Clean },
      variable_properties: default_properties(),
    })
  }
  for name in @semantics.special_integer_variable_names() {
    state = set_global_value(state, name, integer_variable_state())
  }
  for name in @semantics.array_variable_names() {
    state = set_global_value(state, name, array_variable_state())
  }
  state
}

///|
fn set_global_value(
  state : InternalState,
  name : String,
  value : VariableState,
) -> InternalState {
  let globals = state.global_values.copy()
  globals.set(name, value)
  { ..state, global_values: globals }
}

///|
fn set_local_value(
  state : InternalState,
  name : String,
  value : VariableState,
) -> InternalState {
  let locals = state.local_values.copy()
  locals.set(name, value)
  { ..state, local_values: locals }
}

///|
fn set_prefix_value(
  state : InternalState,
  name : String,
  value : VariableState,
) -> InternalState {
  let prefix = state.prefix_values.copy()
  prefix.set(name, value)
  { ..state, prefix_values: prefix }
}

///|
fn set_function_targets(
  state : InternalState,
  name : String,
  targets : Set[FunctionTarget],
) -> InternalState {
  let functions = state.function_targets.copy()
  functions.set(name, targets)
  { ..state, function_targets: functions }
}

///|
fn set_exit_codes(
  state : InternalState,
  exit_codes : Set[CfgAstId],
) -> InternalState {
  { ..state, exit_codes: exit_codes.copy() }
}

///|
fn set_single_exit_code(state : InternalState, id : CfgAstId) -> InternalState {
  set_exit_codes(state, singleton_set(id))
}

///|
fn clear_prefix_values(state : InternalState) -> InternalState {
  { ..state, prefix_values: Map([]) }
}

///|
fn mark_unreachable(state : InternalState) -> InternalState {
  { ..state, reachable: false }
}

///|
fn read_global(state : InternalState, name : String) -> VariableState {
  if state.global_values.get(name) is Some(value) {
    value
  } else {
    unknown_variable_state()
  }
}

///|
fn read_local(state : InternalState, name : String) -> VariableState {
  if state.local_values.get(name) is Some(value) {
    value
  } else {
    unset_variable_state()
  }
}

///|
fn read_variable_with_scope(
  state : InternalState,
  name : String,
) -> (VariableState, CfgScope) {
  if state.prefix_values.get(name) is Some(value) {
    (value, Prefix)
  } else if state.local_values.get(name) is Some(value) {
    (value, Local)
  } else if state.global_values.get(name) is Some(value) {
    (value, Global)
  } else {
    (unknown_variable_state(), Global)
  }
}

///|
fn read_variable(state : InternalState, name : String) -> VariableState {
  read_variable_with_scope(state, name).0
}

///|
fn read_function_targets(
  state : InternalState,
  name : String,
) -> Set[FunctionTarget] {
  if state.function_targets.get(name) is Some(targets) {
    targets
  } else {
    unknown_function_targets()
  }
}

///|
fn write_variable(
  state : InternalState,
  name : String,
  value : VariableState,
) -> InternalState {
  match read_variable_with_scope(state, name).1 {
    Global => set_global_value(state, name, value)
    Local => set_local_value(state, name, value)
    Prefix => set_local_value(state, name, value)
  }
}

///|
fn update_variable_value(
  state : InternalState,
  name : String,
  value : VariableValue,
) -> InternalState {
  let current = read_variable_with_scope(state, name)
  let next = {
    variable_value: value,
    variable_properties: current.0.variable_properties,
  }
  match current.1 {
    Global => set_global_value(state, name, next)
    Local => set_local_value(state, name, next)
    Prefix => set_local_value(state, name, next)
  }
}

///|
fn update_global_value(
  state : InternalState,
  name : String,
  value : VariableValue,
) -> InternalState {
  let current = read_global(state, name)
  set_global_value(state, name, {
    variable_value: value,
    variable_properties: current.variable_properties,
  })
}

///|
fn update_local_value(
  state : InternalState,
  name : String,
  value : VariableValue,
) -> InternalState {
  let current = read_local(state, name)
  set_local_value(state, name, {
    variable_value: value,
    variable_properties: current.variable_properties,
  })
}

///|
fn update_prefix_value(
  state : InternalState,
  name : String,
  value : VariableValue,
) -> InternalState {
  set_prefix_value(state, name, {
    variable_value: value,
    variable_properties: default_properties(),
  })
}

///|
fn set_props(
  state : InternalState,
  scope : CfgScope?,
  name : String,
  props : Array[CfgVariableProp],
) -> InternalState {
  match scope {
    Some(Global) =>
      set_global_value(
        state,
        name,
        add_properties_to_state(read_global(state, name), props),
      )
    Some(Local) =>
      set_local_value(
        state,
        name,
        add_properties_to_state(read_local(state, name), props),
      )
    Some(Prefix) =>
      set_local_value(
        state,
        name,
        add_properties_to_state(read_local(state, name), props),
      )
    None =>
      write_variable(
        state,
        name,
        add_properties_to_state(read_variable(state, name), props),
      )
  }
}

///|
fn unset_props(
  state : InternalState,
  scope : CfgScope?,
  name : String,
  props : Array[CfgVariableProp],
) -> InternalState {
  match scope {
    Some(Global) =>
      set_global_value(
        state,
        name,
        remove_properties_from_state(read_global(state, name), props),
      )
    Some(Local) =>
      set_local_value(
        state,
        name,
        remove_properties_from_state(read_local(state, name), props),
      )
    Some(Prefix) =>
      set_local_value(
        state,
        name,
        remove_properties_from_state(read_local(state, name), props),
      )
    None =>
      write_variable(
        state,
        name,
        remove_properties_from_state(read_variable(state, name), props),
      )
  }
}

///|
fn materialize_visible_variables(
  state : InternalState,
) -> Map[String, VariableState] {
  let values = state.global_values.copy()
  state.local_values.each(fn(name, variable) { values.set(name, variable) })
  state.prefix_values.each(fn(name, variable) { values.set(name, variable) })
  values
}

///|
fn internal_to_program_state(state : InternalState) -> ProgramState {
  {
    variables_in_scope: materialize_visible_variables(state),
    exit_codes: state.exit_codes.copy(),
    state_is_reachable: state.reachable,
  }
}

///|
fn merge_state_map(
  lhs : Map[String, VariableState],
  rhs : Map[String, VariableState],
  missing : VariableState,
) -> Map[String, VariableState] {
  merge_state_map_with_fallbacks(lhs, rhs, fn(_) { missing }, fn(_) { missing })
}

///|
fn merge_state_map_with_fallbacks(
  lhs : Map[String, VariableState],
  rhs : Map[String, VariableState],
  lhs_fallback : (String) -> VariableState,
  rhs_fallback : (String) -> VariableState,
) -> Map[String, VariableState] {
  let result = lhs.copy()
  rhs.each(fn(name, value) {
    if result.get(name) is Some(existing) {
      result.set(name, merge_variable_state(existing, value))
    } else {
      result.set(name, merge_variable_state(lhs_fallback(name), value))
    }
  })
  lhs.each(fn(name, value) {
    if !rhs.contains(name) {
      result.set(name, merge_variable_state(value, rhs_fallback(name)))
    }
  })
  result
}

///|
fn merge_function_target_map(
  lhs : Map[String, Set[FunctionTarget]],
  rhs : Map[String, Set[FunctionTarget]],
) -> Map[String, Set[FunctionTarget]] {
  let result = lhs.copy()
  rhs.each(fn(name, targets) {
    if result.get(name) is Some(existing) {
      result.set(name, union_set(existing, targets))
    } else {
      result.set(name, union_set(unknown_function_targets(), targets))
    }
  })
  lhs.each(fn(name, targets) {
    if !rhs.contains(name) {
      result.set(name, union_set(targets, unknown_function_targets()))
    }
  })
  result
}

///|
fn merge_internal_state(
  lhs : InternalState,
  rhs : InternalState,
) -> InternalState {
  if !lhs.reachable {
    return rhs
  }
  if !rhs.reachable {
    return lhs
  }
  {
    global_values: merge_state_map_with_fallbacks(
      lhs.global_values,
      rhs.global_values,
      fn(name) { read_global(lhs, name) },
      fn(name) { read_global(rhs, name) },
    ),
    local_values: merge_state_map_with_fallbacks(
      lhs.local_values,
      rhs.local_values,
      fn(name) { read_variable(lhs, name) },
      fn(name) { read_variable(rhs, name) },
    ),
    prefix_values: merge_state_map_with_fallbacks(
      lhs.prefix_values,
      rhs.prefix_values,
      fn(name) { read_variable(lhs, name) },
      fn(name) { read_variable(rhs, name) },
    ),
    function_targets: merge_function_target_map(
      lhs.function_targets,
      rhs.function_targets,
    ),
    exit_codes: union_set(lhs.exit_codes, rhs.exit_codes),
    reachable: true,
  }
}

///|
fn compute_value_from_part(
  state : InternalState,
  part : CfgStringPart,
) -> VariableValue {
  match part {
    Literal(text) => literal_to_variable_value(text)
    Integer => unknown_integer_value()
    Unknown => unknown_variable_value()
    Variable(name) =>
      if is_special_integer_name(name) {
        unknown_integer_value()
      } else {
        let current = read_variable(state, name)
        if all_property_sets_have_integer(current.variable_properties) {
          unknown_integer_value()
        } else {
          current.variable_value
        }
      }
  }
}

///|
fn cfg_value_to_variable_value(
  state : InternalState,
  value : CfgValue,
) -> VariableValue {
  match value {
    Uninitialized => unset_variable_value()
    Array => array_variable_value()
    String => unknown_variable_value()
    Integer => unknown_integer_value()
    Computed(_, parts) => {
      let mut current = empty_string_value()
      for part in parts {
        current = append_variable_value(
          current,
          compute_value_from_part(state, part),
        )
      }
      current
    }
  }
}

///|
fn process_effect(state : InternalState, effect : CfgEffect) -> InternalState {
  match effect {
    SetProps(scope, name, props) => set_props(state, scope, name, props)
    UnsetProps(scope, name, props) => unset_props(state, scope, name, props)
    ReadVariable(_) => state
    WriteVariable(name, value) =>
      update_variable_value(
        state,
        name,
        cfg_value_to_variable_value(state, value),
      )
    WriteGlobal(name, value) =>
      update_global_value(
        state,
        name,
        cfg_value_to_variable_value(state, value),
      )
    WriteLocal(name, value) =>
      update_local_value(state, name, cfg_value_to_variable_value(state, value))
    WritePrefix(name, value) =>
      update_prefix_value(
        state,
        name,
        cfg_value_to_variable_value(state, value),
      )
    DefineFunction(name, _, entry, exit_) =>
      set_function_targets(
        state,
        name,
        singleton_set(Definition(name, entry, exit_)),
      )
    Undefine(name) =>
      set_function_targets(
        write_variable(state, name, unset_variable_state()),
        name,
        unknown_function_targets(),
      )
    UndefineVariable(name) =>
      write_variable(state, name, unset_variable_state())
    UndefineFunction(name) =>
      set_function_targets(state, name, unknown_function_targets())
    UndefineNameref(name) => write_variable(state, name, unset_variable_state())
    HintArray(_) => state
    HintDefined(_) => state
  }
}

///|
fn is_special_integer_name(name : String) -> Bool {
  @semantics.is_special_integer_variable(name)
}

///|
fn literal_to_variable_value(text : String) -> VariableValue {
  {
    literal_value: Some(text),
    possible_kinds: singleton_set(String),
    space_status: literal_to_space_status(text),
    numerical_status: literal_to_numerical_status(text),
  }
}

///|
fn literal_to_space_status(text : String) -> SpaceStatus {
  if text == "" {
    return Empty
  }
  if !(text.contains(" ") ||
    text.contains("\t") ||
    text.contains("\n") ||
    text.contains("*") ||
    text.contains("?") ||
    text.contains("[")) {
    return Clean
  }
  Dirty
}

///|
fn literal_to_numerical_status(text : String) -> NumericalStatus {
  if text == "" {
    return Empty
  }
  let view = text[:]
  if view.length() == 0 {
    return Empty
  }
  let mut start = 0
  if view[0] == '-' {
    if view.length() == 1 {
      return Unknown
    }
    start = 1
  }
  let mut i = start
  while i < view.length() {
    if !is_digit(view[i]) {
      return Unknown
    }
    i += 1
  }
  Definitely
}

///|
fn is_digit(ch : UInt16) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn build_context(cfg : CFG) -> AnalysisContext {
  let count = cfg.nodes.length()
  let flow_predecessors = init_node_id_grid(count)
  let successors = init_node_id_grid(count)
  for edge in cfg.graph_edges {
    successors[edge.from.to_int()].push(edge.to)
    if edge.kind == Flow || edge.kind == Exit {
      flow_predecessors[edge.to.to_int()].push(edge.from)
    }
  }
  {
    cfg,
    flow_predecessors,
    successors,
    cache: Ref(Map([])),
    invocations: Ref([]),
    invoked_functions: Ref(Set([])),
  }
}

///|
fn init_node_id_grid(count : Int) -> Array[Array[CfgNodeId]] {
  let values : Array[Array[CfgNodeId]] = []
  for _ in 0..<count {
    values.push([])
  }
  values
}

///|
fn init_state_grid(count : Int) -> Array[(InternalState, InternalState)?] {
  let values : Array[(InternalState, InternalState)?] = []
  for _ in 0..<count {
    values.push(None)
  }
  values
}

///|
fn init_program_state_grid(count : Int) -> Array[(ProgramState, ProgramState)?] {
  let values : Array[(ProgramState, ProgramState)?] = []
  for _ in 0..<count {
    values.push(None)
  }
  values
}

///|
fn stack_with(stack : Array[CfgNodeId], id : CfgNodeId) -> Array[CfgNodeId] {
  let next = copy_node_ids(stack)
  next.push(id)
  next
}

///|
fn node_kind_at(ctx : AnalysisContext, id : CfgNodeId) -> CfgNodeKind {
  if node_at(ctx.cfg, id) is Some(node) {
    node.kind
  } else {
    panic()
  }
}

///|
fn cached_invocation_for(
  ctx : AnalysisContext,
  entry : CfgNodeId,
  input : InternalState,
) -> InvocationResult? {
  if ctx.cache.val.get(entry) is Some(values) {
    for value in values {
      if value.input == input {
        return Some(value)
      }
    }
  }
  None
}

///|
fn store_invocation(ctx : AnalysisContext, result : InvocationResult) -> Unit {
  let cache = ctx.cache.val.copy()
  let values = if cache.get(result.entry) is Some(values) { values } else { [] }
  values.push(result)
  cache.set(result.entry, values)
  ctx.cache.val = cache

  let invocations = copy_invocations(ctx.invocations.val)
  invocations.push(result)
  ctx.invocations.val = invocations
}

///|
fn copy_invocations(
  values : Array[InvocationResult],
) -> Array[InvocationResult] {
  let result : Array[InvocationResult] = []
  for value in values {
    result.push(value)
  }
  result
}

///|
fn run_invocation(
  ctx : AnalysisContext,
  entry : CfgNodeId,
  exit_ : CfgNodeId,
  input : InternalState,
  stack : Array[CfgNodeId],
) -> InvocationResult {
  if cached_invocation_for(ctx, entry, input) is Some(result) {
    result
  } else {
    let states = solve_invocation(ctx, entry, input, stack)
    let exit_state = match states.get(exit_.to_int()) {
      Some(Some((_, outgoing))) => outgoing
      _ => mark_unreachable(input)
    }
    let result = { entry, input, states, exit_state }
    store_invocation(ctx, result)
    result
  }
}

///|
fn enqueue_node(
  queue : Array[CfgNodeId],
  pending : Array[Bool],
  id : CfgNodeId,
) -> Unit {
  let index = id.to_int()
  if pending[index] {
    return
  }
  pending[index] = true
  queue.push(id)
}

///|
fn invocation_input_for_node(
  ctx : AnalysisContext,
  states : Array[(InternalState, InternalState)?],
  entry : CfgNodeId,
  input : InternalState,
  node : CfgNodeId,
) -> InternalState {
  let preds = ctx.flow_predecessors[node.to_int()]
  if preds.length() == 0 {
    if node == entry {
      return input
    }
    return empty_internal_state()
  }
  let mut current : InternalState? = None
  for pred in preds {
    match states.get(pred.to_int()) {
      Some(Some((_, outgoing))) if outgoing.reachable =>
        current = if current is Some(existing) {
          Some(merge_internal_state(existing, outgoing))
        } else {
          Some(outgoing)
        }
      _ => ()
    }
  }
  if current is Some(state) {
    state
  } else {
    unreachable_internal_state()
  }
}

///|
fn transfer_command(
  ctx : AnalysisContext,
  state : InternalState,
  command_name : String?,
  stack : Array[CfgNodeId],
) -> InternalState {
  if command_name is Some(name) {
    let targets = read_function_targets(state, name)
    let mut current : InternalState? = None
    for target in targets {
      let next = transfer_function_target(ctx, state, target, stack)
      current = if current is Some(existing) {
        Some(merge_internal_state(existing, next))
      } else {
        Some(next)
      }
    }
    if current is Some(result) {
      result
    } else {
      state
    }
  } else {
    state
  }
}

///|
fn transfer_function_target(
  ctx : AnalysisContext,
  state : InternalState,
  target : FunctionTarget,
  stack : Array[CfgNodeId],
) -> InternalState {
  match target {
    Unknown => state
    Definition(_, entry, exit_) =>
      if contains_node_id(stack, entry) {
        state
      } else {
        ctx.invoked_functions.val.add(entry)
        let result = run_invocation(
          ctx,
          entry,
          exit_,
          state,
          stack_with(stack, entry),
        )
        {
          ..result.exit_state,
          local_values: state.local_values.copy(),
          prefix_values: state.prefix_values.copy(),
        }
      }
  }
}

///|
fn transfer_subshell(
  ctx : AnalysisContext,
  state : InternalState,
  entry : CfgNodeId,
  exit_ : CfgNodeId,
  stack : Array[CfgNodeId],
) -> InternalState {
  let result = run_invocation(
    ctx,
    entry,
    exit_,
    state,
    stack_with(stack, entry),
  )
  { ..state, exit_codes: result.exit_state.exit_codes.copy() }
}

///|
fn transfer_node(
  ctx : AnalysisContext,
  node : CfgNodeId,
  input : InternalState,
  stack : Array[CfgNodeId],
) -> InternalState {
  if !input.reachable {
    return input
  }
  match node_kind_at(ctx, node) {
    Structural => input
    EntryPoint(_) => input
    DropPrefixAssignments => clear_prefix_values(input)
    ApplyEffects(effects) => {
      let mut current = input
      for tagged in effects {
        current = process_effect(current, tagged.effect)
      }
      current
    }
    ExecuteCommand(command_name) =>
      transfer_command(ctx, input, command_name, stack)
    ExecuteSubshell(_, entry, exit_) =>
      transfer_subshell(ctx, input, entry, exit_, stack)
    SetExitCode(id) => set_single_exit_code(input, id)
    ImpliedExit => input
    ResolvedExit => input
    UnresolvedExit => mark_unreachable(input)
    Unreachable => mark_unreachable(input)
    SetBackgroundPid(_) => input
  }
}

///|
fn solve_invocation(
  ctx : AnalysisContext,
  entry : CfgNodeId,
  input : InternalState,
  stack : Array[CfgNodeId],
) -> Array[(InternalState, InternalState)?] {
  let queue : Array[CfgNodeId] = []
  let pending = init_pending_flags(ctx.cfg.nodes.length())
  let states = init_state_grid(ctx.cfg.nodes.length())
  enqueue_node(queue, pending, entry)
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head += 1
    pending[node.to_int()] = false

    let incoming = invocation_input_for_node(ctx, states, entry, input, node)
    let outgoing = transfer_node(ctx, node, incoming, stack)
    let next_pair = Some((incoming, outgoing))
    let changed = match states[node.to_int()] {
      Some((old_incoming, old_outgoing)) =>
        old_incoming != incoming || old_outgoing != outgoing
      None => true
    }
    states[node.to_int()] = next_pair
    if changed {
      for successor in ctx.successors[node.to_int()] {
        enqueue_node(queue, pending, successor)
      }
    }
  }
  states
}

///|
fn init_pending_flags(count : Int) -> Array[Bool] {
  let values : Array[Bool] = []
  for _ in 0..<count {
    values.push(false)
  }
  values
}

///|
fn merge_program_state(lhs : ProgramState, rhs : ProgramState) -> ProgramState {
  {
    variables_in_scope: merge_state_map(
      lhs.variables_in_scope,
      rhs.variables_in_scope,
      unset_variable_state(),
    ),
    exit_codes: union_set(lhs.exit_codes, rhs.exit_codes),
    state_is_reachable: lhs.state_is_reachable || rhs.state_is_reachable,
  }
}

///|
fn merge_node_pair(
  lhs : (ProgramState, ProgramState),
  rhs : (ProgramState, ProgramState),
) -> (ProgramState, ProgramState) {
  (merge_program_state(lhs.0, rhs.0), merge_program_state(lhs.1, rhs.1))
}

///|
fn merge_invocations(
  cfg : CFG,
  invocations : Array[InvocationResult],
) -> Array[(ProgramState, ProgramState)?] {
  let merged = init_program_state_grid(cfg.nodes.length())
  for invocation in invocations {
    for i in 0..<invocation.states.length() {
      match invocation.states[i] {
        Some((incoming, outgoing)) => {
          let next = (
            internal_to_program_state(incoming),
            internal_to_program_state(outgoing),
          )
          merged[i] = if merged[i] is Some(current) {
            Some(merge_node_pair(current, next))
          } else {
            Some(next)
          }
        }
        None => ()
      }
    }
  }
  merged
}

///|
fn complete_node_states(
  cfg : CFG,
  states : Array[(ProgramState, ProgramState)?],
) -> Array[(ProgramState, ProgramState)?] {
  let completed = init_program_state_grid(cfg.nodes.length())
  let unreachable_state = internal_to_program_state(
    unreachable_internal_state(),
  )
  let unreachable_pair = (unreachable_state, unreachable_state)
  for i in 0..<completed.length() {
    completed[i] = match states.get(i) {
      Some(Some(value)) => Some(value)
      _ => Some(unreachable_pair)
    }
  }
  completed
}

///|
fn straggler_state(root_exit : InternalState) -> InternalState {
  { ..root_exit, exit_codes: Set([]) }
}

///|
fn nested_straggler_state(state : InternalState) -> InternalState {
  { ..straggler_state(state), local_values: Map([]), prefix_values: Map([]) }
}

///|
fn declared_function_entries(
  state : InternalState,
) -> Map[CfgNodeId, FunctionTarget] {
  let result : Map[CfgNodeId, FunctionTarget] = Map([])
  state.function_targets.each(fn(_, targets) {
    for target in targets {
      match target {
        Definition(_, entry, _) => result.set(entry, target)
        Unknown => ()
      }
    }
  })
  result
}

///|
fn enqueue_declared_stragglers(
  queue : Array[PendingStraggler],
  seen : Set[CfgNodeId],
  input : InternalState,
) -> Unit {
  declared_function_entries(input).each(fn(entry, target) {
    if !seen.contains(entry) {
      seen.add(entry)
      queue.push({ input, target })
    }
  })
}

///|
fn run_stragglers(ctx : AnalysisContext, state : InternalState) -> Unit {
  let queue : Array[PendingStraggler] = []
  let seen : Set[CfgNodeId] = Set([])
  for entry in ctx.invoked_functions.val {
    seen.add(entry)
  }
  enqueue_declared_stragglers(queue, seen, state)
  let mut head = 0
  while head < queue.length() {
    let pending = queue[head]
    head += 1
    match pending.target {
      Definition(_, entry, exit_) => {
        let result = run_invocation(ctx, entry, exit_, pending.input, [entry])
        enqueue_declared_stragglers(
          queue,
          seen,
          nested_straggler_state(result.exit_state),
        )
      }
      Unknown => ()
    }
  }
}

///|
/// Runs CFG dataflow and returns the resulting analysis object.
pub fn analyze_control_flow(cfg : CFG) -> CfgAnalysis {
  let context = build_context(cfg)
  let root_range = if id_to_range(cfg, root_ast_id(cfg)) is Some(range) {
    range
  } else {
    panic()
  }
  let env = create_environment_state()
  let root = run_invocation(context, root_range.0, root_range.1, env, [
    root_range.0,
  ])
  let live_node_states = complete_node_states(
    cfg,
    merge_invocations(cfg, context.invocations.val),
  )
  run_stragglers(context, straggler_state(root.exit_state))
  {
    cfg,
    live_node_states,
    node_states: complete_node_states(
      cfg,
      merge_invocations(cfg, context.invocations.val),
    ),
  }
}

///|
fn node_state_at(
  analysis : CfgAnalysis,
  node : CfgNodeId,
) -> (ProgramState, ProgramState)? {
  if analysis.node_states.get(node.to_int()) is Some(value) {
    value
  } else {
    None
  }
}

///|
fn live_node_state_at(
  analysis : CfgAnalysis,
  node : CfgNodeId,
) -> (ProgramState, ProgramState)? {
  if analysis.live_node_states.get(node.to_int()) is Some(value) {
    value
  } else {
    None
  }
}

///|
/// Returns the abstract state flowing into one CFG node.
pub fn incoming_state_of_node(
  analysis : CfgAnalysis,
  node : CfgNodeId,
) -> ProgramState? {
  match node_state_at(analysis, node) {
    Some((incoming, _)) => Some(incoming)
    None => None
  }
}

///|
/// Returns the abstract state flowing out of one CFG node.
pub fn outgoing_state_of_node(
  analysis : CfgAnalysis,
  node : CfgNodeId,
) -> ProgramState? {
  match node_state_at(analysis, node) {
    Some((_, outgoing)) => Some(outgoing)
    None => None
  }
}

///|
/// Returns the abstract state flowing into the CFG range for one AST id.
pub fn incoming_state_of_ast(
  analysis : CfgAnalysis,
  id : CfgAstId,
) -> ProgramState? {
  match id_to_range(analysis.cfg, id) {
    Some((start, _)) => incoming_state_of_node(analysis, start)
    None => None
  }
}

///|
/// Returns the abstract state flowing out of the CFG range for one AST id.
pub fn outgoing_state_of_ast(
  analysis : CfgAnalysis,
  id : CfgAstId,
) -> ProgramState? {
  match id_to_range(analysis.cfg, id) {
    Some((_, end_)) => outgoing_state_of_node(analysis, end_)
    None => None
  }
}

///|
/// Reports whether one AST id post-dominates another according to the analysis.
pub fn does_post_dominate(
  analysis : CfgAnalysis,
  target : CfgAstId,
  base : CfgAstId,
) -> Bool {
  post_dominates(analysis.cfg, target, base)
}

///|
/// Reports whether any CFG node associated with an AST id is reachable.
pub fn command_is_reachable(analysis : CfgAnalysis, id : CfgAstId) -> Bool {
  for node in id_to_nodes(analysis.cfg, id) {
    match live_node_state_at(analysis, node) {
      Some((_, outgoing)) if outgoing.state_is_reachable => return true
      _ => ()
    }
  }
  false
}

///|
fn variable_state_in_scope(
  state : ProgramState,
  name : String,
) -> VariableState? {
  state.variables_in_scope.get(name)
}

///|
/// Reports whether a variable may have been declared with the integer
/// attribute.
pub fn variable_may_be_declared_integer(
  state : ProgramState,
  name : String,
) -> Bool {
  if variable_state_in_scope(state, name) is Some(variable) {
    property_sets_have_integer(variable.variable_properties)
  } else {
    false
  }
}

///|
/// Reports whether a variable may currently hold an integer-like value.
pub fn variable_may_be_assigned_integer(
  state : ProgramState,
  name : String,
) -> Bool {
  if variable_state_in_scope(state, name) is Some(variable) {
    variable.variable_value.numerical_status >= Maybe ||
    kind_is_possible(variable.variable_value, Integer)
  } else {
    false
  }
}

///|
/// Reports whether a variable may currently hold an array value.
pub fn variable_may_be_array(state : ProgramState, name : String) -> Bool {
  if variable_state_in_scope(state, name) is Some(variable) {
    kind_is_possible(variable.variable_value, Array) ||
    property_sets_have_array(variable.variable_properties)
  } else {
    false
  }
}

///|
/// Reports whether a variable may currently be unset.
pub fn variable_may_be_unset(state : ProgramState, name : String) -> Bool {
  if variable_state_in_scope(state, name) is Some(variable) {
    kind_is_possible(variable.variable_value, Unset)
  } else {
    false
  }
}
