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
  let result : Set[A] = Set::new()
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
  value_with_kind(
    VariableKind::String,
    None,
    SpaceStatus::Dirty,
    NumericalStatus::Unknown,
  )
}

///|
fn empty_string_value() -> VariableValue {
  value_with_kind(
    VariableKind::String,
    Some(""),
    SpaceStatus::Empty,
    NumericalStatus::Empty,
  )
}

///|
fn unset_variable_value() -> VariableValue {
  value_with_kind(
    VariableKind::Unset,
    Some(""),
    SpaceStatus::Empty,
    NumericalStatus::Empty,
  )
}

///|
fn array_variable_value() -> VariableValue {
  value_with_kind(
    VariableKind::Array,
    None,
    SpaceStatus::Dirty,
    NumericalStatus::Unknown,
  )
}

///|
fn unknown_integer_value() -> VariableValue {
  value_with_kind(
    VariableKind::Integer,
    None,
    SpaceStatus::Clean,
    NumericalStatus::Definitely,
  )
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
    global_values: Map::new(),
    local_values: Map::new(),
    prefix_values: Map::new(),
    function_targets: Map::new(),
    exit_codes: Set::new(),
    reachable: true,
  }
}

///|
fn unreachable_internal_state() -> InternalState {
  { ..empty_internal_state(), reachable: false }
}

///|
fn unknown_function_targets() -> Set[FunctionTarget] {
  singleton_set(FunctionTarget::Unknown)
}

///|
fn property_set_add(
  props : VariablePropertySet,
  prop : CfgVariableProp,
) -> VariablePropertySet {
  match prop {
    CfgVariableProp::Export => { ..props, exported: true }
    CfgVariableProp::Array => { ..props, array_: true }
    CfgVariableProp::Associative => { ..props, associative: true }
    CfgVariableProp::Integer => { ..props, integer: true }
  }
}

///|
fn property_set_remove(
  props : VariablePropertySet,
  prop : CfgVariableProp,
) -> VariablePropertySet {
  match prop {
    CfgVariableProp::Export => { ..props, exported: false }
    CfgVariableProp::Array => { ..props, array_: false }
    CfgVariableProp::Associative => { ..props, associative: false }
    CfgVariableProp::Integer => { ..props, integer: false }
  }
}

///|
fn add_properties_to_sets(
  property_sets : Set[VariablePropertySet],
  props : Array[CfgVariableProp],
) -> Set[VariablePropertySet] {
  let result : Set[VariablePropertySet] = Set::new()
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
  let result : Set[VariablePropertySet] = Set::new()
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
  if contains_prop(props, CfgVariableProp::Array) ||
    contains_prop(props, CfgVariableProp::Associative) {
    next_value = ensure_possible_kind(next_value, VariableKind::Array)
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
    (SpaceStatus::Empty, other) => other
    (other, SpaceStatus::Empty) => other
    (SpaceStatus::Clean, SpaceStatus::Clean) => SpaceStatus::Clean
    _ => SpaceStatus::Dirty
  }
}

///|
fn merge_numerical_status(
  lhs : NumericalStatus,
  rhs : NumericalStatus,
) -> NumericalStatus {
  match (lhs, rhs) {
    (NumericalStatus::Definitely, NumericalStatus::Definitely) =>
      NumericalStatus::Definitely
    (NumericalStatus::Definitely, _) | (_, NumericalStatus::Definitely) =>
      NumericalStatus::Maybe
    (NumericalStatus::Maybe, _) | (_, NumericalStatus::Maybe) =>
      NumericalStatus::Maybe
    (NumericalStatus::Empty, NumericalStatus::Empty) => NumericalStatus::Empty
    _ => NumericalStatus::Unknown
  }
}

///|
fn append_space_status(lhs : SpaceStatus, rhs : SpaceStatus) -> SpaceStatus {
  match (lhs, rhs) {
    (SpaceStatus::Empty, other) => other
    (other, SpaceStatus::Empty) => other
    (SpaceStatus::Clean, SpaceStatus::Clean) => SpaceStatus::Clean
    _ => SpaceStatus::Dirty
  }
}

///|
fn append_numerical_status(
  lhs : NumericalStatus,
  rhs : NumericalStatus,
) -> NumericalStatus {
  match (lhs, rhs) {
    (NumericalStatus::Empty, other) => other
    (other, NumericalStatus::Empty) => other
    (NumericalStatus::Definitely, NumericalStatus::Definitely) =>
      NumericalStatus::Definitely
    (NumericalStatus::Unknown, _) | (_, NumericalStatus::Unknown) =>
      NumericalStatus::Unknown
    _ => NumericalStatus::Maybe
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
    possible_kinds: singleton_set(VariableKind::String),
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
      variable_value: {
        ..unknown_variable_value(),
        space_status: SpaceStatus::Clean,
      },
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
  { ..state, prefix_values: Map::new() }
}

///|
fn mark_unreachable(state : InternalState) -> InternalState {
  { ..state, reachable: false }
}

///|
fn read_global(state : InternalState, name : String) -> VariableState {
  match state.global_values.get(name) {
    Some(value) => value
    None => unknown_variable_state()
  }
}

///|
fn read_local(state : InternalState, name : String) -> VariableState {
  match state.local_values.get(name) {
    Some(value) => value
    None => unset_variable_state()
  }
}

///|
fn read_variable_with_scope(
  state : InternalState,
  name : String,
) -> (VariableState, CfgScope) {
  match state.prefix_values.get(name) {
    Some(value) => (value, CfgScope::Prefix)
    None =>
      match state.local_values.get(name) {
        Some(value) => (value, CfgScope::Local)
        None =>
          match state.global_values.get(name) {
            Some(value) => (value, CfgScope::Global)
            None => (unknown_variable_state(), CfgScope::Global)
          }
      }
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
  match state.function_targets.get(name) {
    Some(targets) => targets
    None => unknown_function_targets()
  }
}

///|
fn write_variable(
  state : InternalState,
  name : String,
  value : VariableState,
) -> InternalState {
  match read_variable_with_scope(state, name).1 {
    CfgScope::Global => set_global_value(state, name, value)
    CfgScope::Local => set_local_value(state, name, value)
    CfgScope::Prefix => set_local_value(state, name, value)
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
    CfgScope::Global => set_global_value(state, name, next)
    CfgScope::Local => set_local_value(state, name, next)
    CfgScope::Prefix => set_local_value(state, name, next)
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
    Some(CfgScope::Global) =>
      set_global_value(
        state,
        name,
        add_properties_to_state(read_global(state, name), props),
      )
    Some(CfgScope::Local) =>
      set_local_value(
        state,
        name,
        add_properties_to_state(read_local(state, name), props),
      )
    Some(CfgScope::Prefix) =>
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
    Some(CfgScope::Global) =>
      set_global_value(
        state,
        name,
        remove_properties_from_state(read_global(state, name), props),
      )
    Some(CfgScope::Local) =>
      set_local_value(
        state,
        name,
        remove_properties_from_state(read_local(state, name), props),
      )
    Some(CfgScope::Prefix) =>
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
    match result.get(name) {
      Some(existing) => result.set(name, merge_variable_state(existing, value))
      None => result.set(name, merge_variable_state(lhs_fallback(name), value))
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
    match result.get(name) {
      Some(existing) => result.set(name, union_set(existing, targets))
      None => result.set(name, union_set(unknown_function_targets(), targets))
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
    CfgStringPart::Literal(text) => literal_to_variable_value(text)
    CfgStringPart::Integer => unknown_integer_value()
    CfgStringPart::Unknown => unknown_variable_value()
    CfgStringPart::Variable(name) =>
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
    CfgValue::Uninitialized => unset_variable_value()
    CfgValue::Array => array_variable_value()
    CfgValue::String => unknown_variable_value()
    CfgValue::Integer => unknown_integer_value()
    CfgValue::Computed(_, parts) => {
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
    CfgEffect::SetProps(scope, name, props) =>
      set_props(state, scope, name, props)
    CfgEffect::UnsetProps(scope, name, props) =>
      unset_props(state, scope, name, props)
    CfgEffect::ReadVariable(_) => state
    CfgEffect::WriteVariable(name, value) =>
      update_variable_value(
        state,
        name,
        cfg_value_to_variable_value(state, value),
      )
    CfgEffect::WriteGlobal(name, value) =>
      update_global_value(
        state,
        name,
        cfg_value_to_variable_value(state, value),
      )
    CfgEffect::WriteLocal(name, value) =>
      update_local_value(state, name, cfg_value_to_variable_value(state, value))
    CfgEffect::WritePrefix(name, value) =>
      update_prefix_value(
        state,
        name,
        cfg_value_to_variable_value(state, value),
      )
    CfgEffect::DefineFunction(name, _, entry, exit_) =>
      set_function_targets(
        state,
        name,
        singleton_set(FunctionTarget::Definition(name, entry, exit_)),
      )
    CfgEffect::Undefine(name) =>
      set_function_targets(
        write_variable(state, name, unset_variable_state()),
        name,
        unknown_function_targets(),
      )
    CfgEffect::UndefineVariable(name) =>
      write_variable(state, name, unset_variable_state())
    CfgEffect::UndefineFunction(name) =>
      set_function_targets(state, name, unknown_function_targets())
    CfgEffect::UndefineNameref(name) =>
      write_variable(state, name, unset_variable_state())
    CfgEffect::HintArray(_) => state
    CfgEffect::HintDefined(_) => state
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
    possible_kinds: singleton_set(VariableKind::String),
    space_status: literal_to_space_status(text),
    numerical_status: literal_to_numerical_status(text),
  }
}

///|
fn literal_to_space_status(text : String) -> SpaceStatus {
  if text == "" {
    return SpaceStatus::Empty
  }
  if !(text.contains(" ") ||
    text.contains("\t") ||
    text.contains("\n") ||
    text.contains("*") ||
    text.contains("?") ||
    text.contains("[")) {
    return SpaceStatus::Clean
  }
  SpaceStatus::Dirty
}

///|
fn literal_to_numerical_status(text : String) -> NumericalStatus {
  if text == "" {
    return NumericalStatus::Empty
  }
  let view = text[:]
  if view.length() == 0 {
    return NumericalStatus::Empty
  }
  let mut start = 0
  if view[0] == '-' {
    if view.length() == 1 {
      return NumericalStatus::Unknown
    }
    start = 1
  }
  let mut i = start
  while i < view.length() {
    if !is_digit(view[i]) {
      return NumericalStatus::Unknown
    }
    i += 1
  }
  NumericalStatus::Definitely
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
    if edge.kind == CfgEdgeKind::Flow || edge.kind == CfgEdgeKind::Exit {
      flow_predecessors[edge.to.to_int()].push(edge.from)
    }
  }
  {
    cfg,
    flow_predecessors,
    successors,
    cache: Ref::new(Map::new()),
    invocations: Ref::new([]),
    invoked_functions: Ref::new(Set::new()),
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
  match node_at(ctx.cfg, id) {
    Some(node) => node.kind
    None => panic()
  }
}

///|
fn cached_invocation_for(
  ctx : AnalysisContext,
  entry : CfgNodeId,
  input : InternalState,
) -> InvocationResult? {
  match ctx.cache.val.get(entry) {
    Some(values) =>
      for value in values {
        if value.input == input {
          return Some(value)
        }
      }
    None => ()
  }
  None
}

///|
fn store_invocation(ctx : AnalysisContext, result : InvocationResult) -> Unit {
  let cache = ctx.cache.val.copy()
  let values = match cache.get(result.entry) {
    Some(values) => values
    None => []
  }
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
  match cached_invocation_for(ctx, entry, input) {
    Some(result) => result
    None => {
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
        current = match current {
          Some(existing) => Some(merge_internal_state(existing, outgoing))
          None => Some(outgoing)
        }
      _ => ()
    }
  }
  match current {
    Some(state) => state
    None => unreachable_internal_state()
  }
}

///|
fn transfer_command(
  ctx : AnalysisContext,
  state : InternalState,
  command_name : String?,
  stack : Array[CfgNodeId],
) -> InternalState {
  match command_name {
    None => state
    Some(name) => {
      let targets = read_function_targets(state, name)
      let mut current : InternalState? = None
      for target in targets {
        let next = transfer_function_target(ctx, state, target, stack)
        current = match current {
          Some(existing) => Some(merge_internal_state(existing, next))
          None => Some(next)
        }
      }
      match current {
        Some(result) => result
        None => state
      }
    }
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
    FunctionTarget::Unknown => state
    FunctionTarget::Definition(_, entry, exit_) =>
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
    CfgNodeKind::Structural => input
    CfgNodeKind::EntryPoint(_) => input
    CfgNodeKind::DropPrefixAssignments => clear_prefix_values(input)
    CfgNodeKind::ApplyEffects(effects) => {
      let mut current = input
      for tagged in effects {
        current = process_effect(current, tagged.effect)
      }
      current
    }
    CfgNodeKind::ExecuteCommand(command_name) =>
      transfer_command(ctx, input, command_name, stack)
    CfgNodeKind::ExecuteSubshell(_, entry, exit_) =>
      transfer_subshell(ctx, input, entry, exit_, stack)
    CfgNodeKind::SetExitCode(id) => set_single_exit_code(input, id)
    CfgNodeKind::ImpliedExit => input
    CfgNodeKind::ResolvedExit => input
    CfgNodeKind::UnresolvedExit => mark_unreachable(input)
    CfgNodeKind::Unreachable => mark_unreachable(input)
    CfgNodeKind::SetBackgroundPid(_) => input
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
          merged[i] = match merged[i] {
            Some(current) => Some(merge_node_pair(current, next))
            None => Some(next)
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
  { ..root_exit, exit_codes: Set::new() }
}

///|
fn nested_straggler_state(state : InternalState) -> InternalState {
  {
    ..straggler_state(state),
    local_values: Map::new(),
    prefix_values: Map::new(),
  }
}

///|
fn declared_function_entries(
  state : InternalState,
) -> Map[CfgNodeId, FunctionTarget] {
  let result : Map[CfgNodeId, FunctionTarget] = Map::new()
  state.function_targets.each(fn(_, targets) {
    for target in targets {
      match target {
        FunctionTarget::Definition(_, entry, _) => result.set(entry, target)
        FunctionTarget::Unknown => ()
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
  let seen : Set[CfgNodeId] = Set::new()
  for entry in ctx.invoked_functions.val {
    seen.add(entry)
  }
  enqueue_declared_stragglers(queue, seen, state)
  let mut head = 0
  while head < queue.length() {
    let pending = queue[head]
    head += 1
    match pending.target {
      FunctionTarget::Definition(_, entry, exit_) => {
        let result = run_invocation(ctx, entry, exit_, pending.input, [entry])
        enqueue_declared_stragglers(
          queue,
          seen,
          nested_straggler_state(result.exit_state),
        )
      }
      FunctionTarget::Unknown => ()
    }
  }
}

///|
/// Runs CFG dataflow and returns the resulting analysis object.
pub fn analyze_control_flow(cfg : CFG) -> CfgAnalysis {
  let context = build_context(cfg)
  let root_range = match id_to_range(cfg, root_ast_id(cfg)) {
    Some(range) => range
    None => panic()
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
  match analysis.node_states.get(node.to_int()) {
    Some(value) => value
    None => None
  }
}

///|
fn live_node_state_at(
  analysis : CfgAnalysis,
  node : CfgNodeId,
) -> (ProgramState, ProgramState)? {
  match analysis.live_node_states.get(node.to_int()) {
    Some(value) => value
    None => None
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
  match variable_state_in_scope(state, name) {
    Some(variable) => property_sets_have_integer(variable.variable_properties)
    None => false
  }
}

///|
/// Reports whether a variable may currently hold an integer-like value.
pub fn variable_may_be_assigned_integer(
  state : ProgramState,
  name : String,
) -> Bool {
  match variable_state_in_scope(state, name) {
    Some(variable) =>
      variable.variable_value.numerical_status >= NumericalStatus::Maybe ||
      kind_is_possible(variable.variable_value, VariableKind::Integer)
    None => false
  }
}

///|
/// Reports whether a variable may currently hold an array value.
pub fn variable_may_be_array(state : ProgramState, name : String) -> Bool {
  match variable_state_in_scope(state, name) {
    Some(variable) =>
      kind_is_possible(variable.variable_value, VariableKind::Array) ||
      property_sets_have_array(variable.variable_properties)
    None => false
  }
}

///|
/// Reports whether a variable may currently be unset.
pub fn variable_may_be_unset(state : ProgramState, name : String) -> Bool {
  match variable_state_in_scope(state, name) {
    Some(variable) =>
      kind_is_possible(variable.variable_value, VariableKind::Unset)
    None => false
  }
}
