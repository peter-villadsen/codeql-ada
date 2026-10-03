with Ada.Command_Line;
with GNAT.OS_Lib;
with System.OS_Lib;
with GNAT.Expect;
with Interfaces.C; use Interfaces.C;

procedure Test is
   use GNAT.OS_Lib;

   function Arg (Number : Positive) return String renames Ada.Command_Line.Argument;

   --  Intermediate subprograms: the tainted value reaches Spawn only through a
   --  parameter, so no intraprocedural analysis can see it.
   procedure Run (Cmd : String) is
      Args    : Argument_List (1 .. 0);
      Success : Boolean;
   begin
      Spawn (Cmd, Args, Success);  -- BAD: Program_Name, procedure overload
   end Run;

   function Get_Arg (N : Positive) return String is
   begin
      return Ada.Command_Line.Argument (N);
   end Get_Arg;

   --  The argument list built from a tainted value, passed as Args.
   procedure Run_With_Arg (Word : String) is
      Args : Argument_List := (1 => new String'(Word));
      Code : Integer;
   begin
      Code := System.OS_Lib.Spawn ("/bin/echo", Args);  -- BAD: Args, System spelling, function overload
   end Run_With_Arg;

   --  Named associations, in an order that differs from the formals'.
   procedure Run_Named (Line : String) is
      Ok : Boolean;
   begin
      GNAT.OS_Lib.Spawn
        (Args => Argument_String_To_List (Line).all, Program_Name => "/bin/sh", Success => Ok);  -- BAD: Args
   end Run_Named;

   --  Non_Blocking_Spawn runs a command just as Spawn does.
   procedure Run_Async (Cmd : String) is
      Args : Argument_List (1 .. 0);
      Pid  : Process_Id;
   begin
      Pid := Non_Blocking_Spawn (Cmd, Args);  -- BAD: Program_Name
   end Run_Async;

   --  Output_File names a file, not a command: not a sink.
   procedure Output_Only (Out_Name : String) is
      Args : Argument_List (1 .. 0);
      Ok   : Boolean;
      Code : Integer;
   begin
      GNAT.OS_Lib.Spawn ("/bin/true", Args, Out_Name, Ok, Code);  -- GOOD
   end Output_Only;

   --  A constant command is not tainted.
   procedure Fixed is
      Args : Argument_List (1 .. 0);
      Ok   : Boolean;
   begin
      Spawn ("/bin/true", Args, Ok);  -- GOOD
   end Fixed;

   --  GNAT.Expect: the command and its arguments are sinks; Input is stdin data.
   procedure Run_Expect (Cmd : String) is
      Pd     : GNAT.Expect.Process_Descriptor;
      Status : aliased Integer;
      Args   : Argument_List (1 .. 0);
   begin
      GNAT.Expect.Non_Blocking_Spawn (Pd, Cmd, Args);  -- BAD: Command
      declare
         Output : constant String :=
           GNAT.Expect.Get_Command_Output ("/bin/cat", Args, Input => Cmd, Status => Status'Access);  -- GOOD: Input
      begin
         null;
      end;
   end Run_Expect;

   --  Imported C functions: by pragma with an external name, by aspect with the
   --  default name ("popen"), and by aspect with an external name.
   function C_System (Command : char_array) return int;
   pragma Import (C, C_System, "system");

   function Popen (Command : char_array; Mode : char_array) return System.Address
     with Import, Convention => C;

   function Run_Program (Path : char_array; Argv : System.Address) return int
     with Import, Convention => C, External_Name => "execv";

   procedure Run_C (Cmd : String) is
      R : int;
      F : System.Address;
   begin
      R := C_System (To_C (Cmd));                         -- BAD: system
      F := Popen (To_C (Cmd), To_C ("r"));                -- BAD: popen command
      F := Popen (To_C ("ls"), To_C (Cmd));               -- GOOD: popen mode
      R := Run_Program (To_C (Cmd), System.Null_Address);  -- BAD: execv
   end Run_C;

   use Ada.Command_Line;
begin
   Run (Argument (1));                -- bare name under a use clause
   Run ("prefix-" & Get_Arg (2));     -- up through a function result, then concatenated
   Run_With_Arg (Arg (3));            -- through a renaming of Argument
   Run_Named (Ada.Command_Line.Argument (4));
   Run_Async (Ada.Command_Line.Argument (6));
   Run_Expect (Ada.Command_Line.Argument (7));
   Run_C (Ada.Command_Line.Argument (8));
   Output_Only (Ada.Command_Line.Argument (5));
   Fixed;
end Test;
