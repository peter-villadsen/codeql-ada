with Ada.Command_Line;
with GNAT.OS_Lib;
with System.OS_Lib;

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

   use Ada.Command_Line;
begin
   Run (Argument (1));                -- bare name under a use clause
   Run ("prefix-" & Get_Arg (2));     -- up through a function result, then concatenated
   Run_With_Arg (Arg (3));            -- through a renaming of Argument
   Run_Named (Ada.Command_Line.Argument (4));
   Run_Async (Ada.Command_Line.Argument (6));
   Output_Only (Ada.Command_Line.Argument (5));
   Fixed;
end Test;
