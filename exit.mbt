///|
#cfg(target="wasm")
fn exit_process(rval : Int32) -> Unit = "wasi_snapshot_preview1" "proc_exit"

///|
#cfg(target="native")
extern "c" fn exit_process(code : Int32) -> Unit = "exit"
