///|
/// Thin native binding used by `main` to terminate with a non-zero exit status.
extern "c" fn exit_process(code : Int) -> Unit = "exit"
