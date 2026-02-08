-- ***************************************************************************
--                  Brick Buster Ascii game
--
--           Copyright (C) 2026 By Ulrik Hørlyk Hjort
--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
-- LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
-- OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
-- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- ***************************************************************************
with Ada.Text_IO;
with Ada.Calendar;
with Ada.Strings.Fixed;

procedure BrickBuster is
   package TIO renames Ada.Text_IO;
   package SF renames Ada.Strings.Fixed;
   use type Ada.Calendar.Time;

   type Point is record
      X : Integer;
      Y : Integer;
   end record;

   type Ball_Type is record
      Pos : Point;
      Vel : Point;
   end record;

   type Brick_Type is record
      Pos : Point;
      Active : Boolean;
   end record;

   Game_Width  : constant Integer := 60;
   Game_Height : constant Integer := 24;
   
   Paddle_Width : constant Integer := 8;
   Paddle_Y     : constant Integer := Game_Height - 2;
   Paddle_X     : Integer := Game_Width / 2 - Paddle_Width / 2;
   
   Ball : Ball_Type := (Pos => (Game_Width / 2, Game_Height / 2),
                        Vel => (1, 1));
   
   Brick_Rows : constant Integer := 5;
   Brick_Cols : constant Integer := 10;
   Brick_Width : constant Integer := 5;
   
   type Brick_Array is array (1 .. Brick_Rows, 1 .. Brick_Cols) of Brick_Type;
   Bricks : Brick_Array;
   
   Score : Integer := 0;
   Lives : Integer := 3;
   Running : Boolean := True;

   function Trim_Image (N : Integer) return String is
      S : constant String := Integer'Image(N);
   begin
      if S(S'First) = ' ' then
         return S(S'First + 1 .. S'Last);
      else
         return S;
      end if;
   end Trim_Image;

   procedure Move_Cursor (Y, X : Integer) is
   begin
      TIO.Put (ASCII.ESC & "[" & Trim_Image(Y) & ";" & Trim_Image(X) & "H");
   end Move_Cursor;

   function Get_Char_Non_Blocking return Character is
      C : Character;
      Available : Boolean := False;
   begin
      TIO.Get_Immediate (C, Available);
      if Available then
         return C;
      else
         return ASCII.NUL;
      end if;
   exception
      when others =>
         return ASCII.NUL;
   end Get_Char_Non_Blocking;

   procedure Clear_Screen is
   begin
      TIO.Put (ASCII.ESC & "[2J");
      TIO.Put (ASCII.ESC & "[H");
      TIO.Flush;
   end Clear_Screen;

   procedure Hide_Cursor is
   begin
      TIO.Put (ASCII.ESC & "[?25l");
      TIO.Flush;
   end Hide_Cursor;

   procedure Show_Cursor is
   begin
      TIO.Put (ASCII.ESC & "[?25h");
      TIO.Flush;
   end Show_Cursor;

   procedure Init_Bricks is
      X_Offset : Integer;
   begin
      for Row in 1 .. Brick_Rows loop
         for Col in 1 .. Brick_Cols loop
            X_Offset := (Col - 1) * Brick_Width + 2;
            Bricks (Row, Col) := (Pos => (X_Offset, Row + 2),
                                  Active => True);
         end loop;
      end loop;
   end Init_Bricks;

   procedure Draw_Border is
   begin
      Move_Cursor (1, 1);
      for X in 0 .. Game_Width + 1 loop
         TIO.Put ("#");
      end loop;
      
      Move_Cursor (Game_Height + 2, 1);
      for X in 0 .. Game_Width + 1 loop
         TIO.Put ("#");
      end loop;
      
      for Y in 2 .. Game_Height + 1 loop
         Move_Cursor (Y, 1);
         TIO.Put ("#");
         Move_Cursor (Y, Game_Width + 2);
         TIO.Put ("#");
      end loop;
   end Draw_Border;

   procedure Draw_Paddle is
   begin
      Move_Cursor (Paddle_Y + 2, Paddle_X + 2);
      for I in 1 .. Paddle_Width loop
         TIO.Put ("=");
      end loop;
   end Draw_Paddle;

   procedure Draw_Ball is
   begin
      Move_Cursor (Ball.Pos.Y + 2, Ball.Pos.X + 2);
      TIO.Put ("O");
   end Draw_Ball;

   procedure Draw_Bricks is
   begin
      for Row in 1 .. Brick_Rows loop
         for Col in 1 .. Brick_Cols loop
            if Bricks (Row, Col).Active then
               declare
                  B : Brick_Type renames Bricks (Row, Col);
               begin
                  Move_Cursor (B.Pos.Y + 2, B.Pos.X + 2);
                  for I in 1 .. Brick_Width - 1 loop
                     TIO.Put ("█");
                  end loop;
               end;
            end if;
         end loop;
      end loop;
   end Draw_Bricks;

   procedure Draw_UI is
   begin
      Move_Cursor (Game_Height + 3, 1);
      TIO.Put ("Score:" & Integer'Image(Score) & "  Lives:" & Integer'Image(Lives) & "  [Q]uit  [A/D] or [Arrows] Move");
   end Draw_UI;

   procedure Update_Ball is
   begin
      Ball.Pos.X := Ball.Pos.X + Ball.Vel.X;
      Ball.Pos.Y := Ball.Pos.Y + Ball.Vel.Y;

      if Ball.Pos.X <= 0 or Ball.Pos.X >= Game_Width then
         Ball.Vel.X := -Ball.Vel.X;
         Ball.Pos.X := Ball.Pos.X + Ball.Vel.X * 2;
      end if;

      if Ball.Pos.Y <= 0 then
         Ball.Vel.Y := -Ball.Vel.Y;
         Ball.Pos.Y := 1;
      end if;

      if Ball.Pos.Y >= Paddle_Y - 1 and Ball.Pos.Y <= Paddle_Y then
         if Ball.Pos.X >= Paddle_X and Ball.Pos.X <= Paddle_X + Paddle_Width then
            Ball.Vel.Y := -Ball.Vel.Y;
            Ball.Pos.Y := Paddle_Y - 2;
            
            declare
               Paddle_Center : constant Integer := Paddle_X + Paddle_Width / 2;
               Offset : constant Integer := Ball.Pos.X - Paddle_Center;
            begin
               if Offset < -2 then
                  Ball.Vel.X := -1;
               elsif Offset > 2 then
                  Ball.Vel.X := 1;
               end if;
            end;
         end if;
      end if;

      if Ball.Pos.Y >= Game_Height then
         Lives := Lives - 1;
         if Lives <= 0 then
            Running := False;
         else
            Ball.Pos := (Game_Width / 2, Game_Height / 2);
            Ball.Vel := (1, -1);
         end if;
      end if;
   end Update_Ball;

   procedure Check_Brick_Collision is
   begin
      for Row in 1 .. Brick_Rows loop
         for Col in 1 .. Brick_Cols loop
            if Bricks (Row, Col).Active then
               declare
                  B : Brick_Type renames Bricks (Row, Col);
               begin
                  if Ball.Pos.Y >= B.Pos.Y and Ball.Pos.Y <= B.Pos.Y + 1 and
                     Ball.Pos.X >= B.Pos.X and
                     Ball.Pos.X < B.Pos.X + Brick_Width then
                     Bricks (Row, Col).Active := False;
                     Ball.Vel.Y := -Ball.Vel.Y;
                     Score := Score + 10;
                     return;
                  end if;
               end;
            end if;
         end loop;
      end loop;
   end Check_Brick_Collision;

   procedure Handle_Input is
      C : Character;
      C2, C3 : Character;
   begin
      C := Get_Char_Non_Blocking;
      
      if C = ASCII.ESC then
         C2 := Get_Char_Non_Blocking;
         if C2 = '[' then
            C3 := Get_Char_Non_Blocking;
            case C3 is
               when 'D' =>  -- Left arrow
                  if Paddle_X > 1 then
                     Paddle_X := Paddle_X - 4;
                  end if;
               when 'C' =>  -- Right arrow
                  if Paddle_X < Game_Width - Paddle_Width - 1 then
                     Paddle_X := Paddle_X + 4;
                  end if;
               when others =>
                  null;
            end case;
         end if;
      else
         case C is
            when 'a' | 'A' =>
               if Paddle_X > 1 then
                  Paddle_X := Paddle_X - 4;
               end if;
            when 'd' | 'D' =>
               if Paddle_X < Game_Width - Paddle_Width - 1 then
                  Paddle_X := Paddle_X + 4;
               end if;
            when 'q' | 'Q' =>
               Running := False;
            when others =>
               null;
         end case;
      end if;
   end Handle_Input;

   Last_Time : Ada.Calendar.Time;
   Current_Time : Ada.Calendar.Time;
   Frame_Duration : constant Duration := 0.08;

begin
   Hide_Cursor;
   Clear_Screen;
   
   Init_Bricks;
   Last_Time := Ada.Calendar.Clock;

   while Running loop
      Clear_Screen;
      Draw_Border;
      Draw_Bricks;
      Draw_Paddle;
      Draw_Ball;
      Draw_UI;
      TIO.Flush;

      Handle_Input;
      Update_Ball;
      Check_Brick_Collision;

      Current_Time := Ada.Calendar.Clock;
      if Current_Time - Last_Time < Frame_Duration then
         delay Frame_Duration - (Current_Time - Last_Time);
      end if;
      Last_Time := Ada.Calendar.Clock;
   end loop;

   Clear_Screen;
   Show_Cursor;
   TIO.Put_Line ("Game Over! Final Score:" & Integer'Image(Score));

exception
   when others =>
      Show_Cursor;
      TIO.Put_Line ("Error occurred");
end BrickBuster;
