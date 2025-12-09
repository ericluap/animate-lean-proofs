import Lean

/-- Configuration for the transform format wrapper -/
structure Config where
  originalLeanFile : String
  targetTheorem : String
  outputFile : String
  keepIntermediate : Bool := false

/-- Parse command line arguments -/
def parseArgs (args : Array String) : IO Config := do
  let mut originalLeanFile : Option String := none
  let mut targetTheorem : Option String := none
  let mut outputFile : Option String := none
  let mut keepIntermediate := false
  let mut idx := 0

  while idx < args.size do
    match args[idx]! with
    | "--original_lean_file" | "-i" =>
      idx := idx + 1
      if idx < args.size then
        originalLeanFile := some args[idx]!
      else
        throw <| IO.userError "Missing value for --original_lean_file"
    | "--target_theorem" | "-t" =>
      idx := idx + 1
      if idx < args.size then
        targetTheorem := some args[idx]!
      else
        throw <| IO.userError "Missing value for --target_theorem"
    | "--output_file" | "-o" =>
      idx := idx + 1
      if idx < args.size then
        outputFile := some args[idx]!
      else
        throw <| IO.userError "Missing value for --output_file"
    | "--keep_intermediate" | "-k" =>
      keepIntermediate := true
    | s => throw <| IO.userError s!"Unknown argument: {s}"
    idx := idx + 1

  match originalLeanFile, targetTheorem, outputFile with
  | some f, some t, some o =>
    return { originalLeanFile := f, targetTheorem := t, outputFile := o, keepIntermediate := keepIntermediate }
  | none, _, _ => throw <| IO.userError "Missing required argument: --original_lean_file"
  | _, none, _ => throw <| IO.userError "Missing required argument: --target_theorem"
  | _, _, none => throw <| IO.userError "Missing required argument: --output_file"

/-- Build command line arguments for transform_format.py -/
def buildPythonArgs (cfg : Config) : Array String :=
  let baseArgs := #["transform_format.py",
                    "--original_lean_file", cfg.originalLeanFile,
                    "--target_theorem", cfg.targetTheorem,
                    "--output_file", cfg.outputFile]
  if cfg.keepIntermediate then
    baseArgs.push "--keep_intermediate"
  else
    baseArgs

/-- Run transform_format.py with the given configuration -/
def runTransformFormat (cfg : Config) : IO Unit := do
  let args := buildPythonArgs cfg
  let proc ← IO.Process.spawn {
    cmd := "python3"
    args := args
    stdout := .inherit
    stderr := .inherit
  }
  let exitCode ← proc.wait
  if exitCode != 0 then
    throw <| IO.userError s!"transform_format.py exited with code {exitCode}"

/-- Read the output file and return its contents -/
def readOutputFile (path : String) : IO String := do
  IO.FS.readFile ⟨path⟩

/-- Main entry point -/
def main (args : List String) : IO UInt32 := do
  try
    let cfg ← parseArgs args.toArray
    runTransformFormat cfg
    let content ← readOutputFile cfg.outputFile
    IO.println content
    return 0
  catch e =>
    IO.eprintln s!"Error: {e}"
    IO.eprintln "Usage: transform_format_wrapper --original_lean_file <file> --target_theorem <theorem> --output_file <output> [--keep_intermediate]"
    return 1
