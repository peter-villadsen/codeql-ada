procedure Test is
   procedure P1 is
      procedure P2 is
         procedure P3 is
            procedure P4 is
               procedure P5 is
                  procedure P6 is
                     procedure P7 is
                        procedure P8 is   --  BAD: nested 8 deep
                        begin
                           null;
                        end P8;
                     begin
                        P8;
                     end P7;
                  begin
                     P7;
                  end P6;
               begin
                  P6;
               end P5;
            begin
               P5;
            end P4;
         begin
            P4;
         end P3;
      begin
         P3;
      end P2;
   begin
      P2;
   end P1;
begin
   P1;
end Test;

package Tasks is
   generic
   package G1 is
      generic
      package G2 is
      end G2;
   end G1;
   task type Outer;
end Tasks;

package body Tasks is
   task body Outer is
      task Inner;
      task body Inner is
      begin
         null;
      end Inner;
   begin
      null;
   end Outer;
end Tasks;
