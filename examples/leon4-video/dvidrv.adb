------------------------------------------------------------------------------
--                                                                          --
--                               GNAT EXAMPLE                               --
--                                                                          --
--                        Copyright (C) 2016, AdaCore                       --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 2,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with GNAT;  see file COPYING.  If not, write --
-- to  the  Free Software Foundation,  51  Franklin  Street,  Fifth  Floor, --
-- Boston, MA 02110-1301, USA.                                              --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------
pragma Ada_2012;

with System;
with Interfaces.Leon3.Irqmp;
with Interfaces; use Interfaces;
with Ada.Text_IO; use Ada.Text_IO;
with I2cm; use I2cm;

package body Dvidrv is

   I2cm_Video_Base : constant := 16#c000_0900#;

   I2cm_Video_Interrupt : constant := 18;

   I2cm_Clock_Prescale : I2cm_Clock_Prescale_Register
     with Address => System'To_Address (I2cm_Video_Base + 16#00#),
     Volatile, Import;

   I2cm_Control : I2cm_Control_Register
     with Address => System'To_Address (I2cm_Video_Base + 16#04#),
     Volatile, Import;

   I2cm_Data : I2cm_Data_Register
     with Address => System'To_Address (I2cm_Video_Base + 16#08#),
     Volatile, Import;

   --  Write only
   I2cm_Command : I2cm_Command_Register
     with Address => System'To_Address (I2cm_Video_Base + 16#0c#),
     Volatile, Import;

   --  Read only
   I2cm_Status : I2cm_Status_Register
     with Address => System'To_Address (I2cm_Video_Base + 16#0c#),
     Volatile, Import;

   I2cm_Ien : constant Boolean := True;

   protected I2c_Prot is
      pragma Interrupt_Priority (System.Interrupt_Priority'First);

      procedure Handler;
      pragma Attach_Handler (Handler, I2cm_Video_Interrupt);

      entry Wait_Tfr;
   private
      It_Pending : Boolean := False;
   end I2c_Prot;

   protected body I2c_Prot is
      procedure Handler is
      begin
         It_Pending := True;
         I2cm_Command := (Sta => False, Sto => False,
                          Wr => False, Rd => False,
                          Ack => False, Iack => True, Res_0 => 0, Res_1 => 0);
      end Handler;

      entry Wait_Tfr when It_Pending is
      begin
         It_Pending := False;
      end Wait_Tfr;
   end I2c_Prot;

   procedure I2c_Start (Addr : Unsigned_8; Ok : out Boolean) is
   begin
      --  Address

      I2cm_Data := (Res => 0, Data => Addr);
      I2cm_Command := (Sta => True, Sto => False,
                       Wr => True, Rd => False,
                       Ack => False, Iack => False, Res_0 => 0, Res_1 => 0);

      if I2cm_Ien then
         I2c_Prot.Wait_Tfr;
      else
         while I2cm_Status.Tip loop
            null;
         end loop;
      end if;

      if I2cm_Status.Rxack then
         Put_Line ("no ack");
         Ok := False;
      else
         Ok := True;
      end if;
   end I2c_Start;

   procedure I2c_Write (Data : Unsigned_8; Stop : Boolean) is
   begin
      I2cm_Data := (Res => 0, Data => Data);
      I2cm_Command := (Sta => False, Sto => Stop,
                       Wr => True, Rd => False,
                       Ack => False, Iack => False, Res_0 => 0, Res_1 => 0);
      if I2cm_Ien then
         I2c_Prot.Wait_Tfr;
      else
         while I2cm_Status.Tip loop
            null;
         end loop;
      end if;
   end I2c_Write;

   procedure I2c_Read (Data : out Unsigned_8; Stop : Boolean) is
   begin
      I2cm_Command := (Sta => False, Sto => Stop,
                       Wr => False, Rd => True,
                       Ack => False, Iack => False, Res_0 => 0, Res_1 => 0);
      if I2cm_Ien then
         I2c_Prot.Wait_Tfr;
      else
         while I2cm_Status.Tip loop
            null;
         end loop;
      end if;

      Data := I2cm_Data.Data;
   end I2c_Read;

   procedure Write (Addr : Unsigned_8; Reg : Unsigned_8; Val : Unsigned_8)
   is
      Ok : Boolean;
   begin
      I2c_Start (Addr, Ok);
      if not Ok then
         return;
      end if;
      I2c_Write (Reg, False);
      I2c_Write (Val, True);
   end Write;

   procedure Read (Addr : Unsigned_8; Reg : Unsigned_8; Val : out Unsigned_8)
   is
      Ok : Boolean;
   begin
      I2c_Start (Addr, Ok);
      if not Ok then
         Val := 0;
         return;
      end if;
      I2c_Write (Reg, False);

      I2c_Start (Addr or 1, Ok);
      if not Ok then
         Val := 0;
         return;
      end if;
      I2c_Read (Val, True);
   end Read;

   procedure Init
   is
      Val : Unsigned_8;
   begin
      I2cm_Control := (Res_0 => 0, En => False, Ien => False, Res_1 => 0);

      --  Prescale = AMBA_clock_Freq / (5 * SCL_Freq) - 1
      I2cm_Clock_Prescale.Prescale :=
        Unsigned_16 (100_000_000 / (5 * 100_000) - 1);

      --  Enable
      I2cm_Control := (Res_0 => 0, En => True, Ien => I2cm_Ien, Res_1 => 0);

      if I2cm_Ien then
         declare
            use Interfaces.Leon3.Irqmp;
         begin
            Interrupt_Mask (1) :=
              Interrupt_Mask (1) or 2**I2cm_Video_Interrupt;
         end;
      end if;

      Read (16#ec#, 16#4a#, Val);
      Put ("VID: ");
      Put (Unsigned_8'Image (Val));

      Read (16#ec#, 16#4b#, Val);
      Put (", DID: ");
      Put_Line (Unsigned_8'Image (Val));

      if True then
         --  AS is 0, so i2c address is 2#1110_110x#
         Write (16#ec#, 16#1c#, 16#04#);
         Write (16#ec#, 16#1d#, 16#45#);
         Write (16#ec#, 16#1e#, 16#c0#);
         Write (16#ec#, 16#1f#, 16#8a#);  -- 16 bit
         Write (16#ec#, 16#21#, 16#00#);  -- DVI
         Write (16#ec#, 16#33#, 16#08#);
         Write (16#ec#, 16#34#, 16#16#);
         Write (16#ec#, 16#36#, 16#60#);
         Write (16#ec#, 16#48#, 16#19#); --  Color Bars
         Write (16#ec#, 16#49#, 16#c0#);
         Write (16#ec#, 16#56#, 16#00#);
      end if;
   end Init;
end Dvidrv;
