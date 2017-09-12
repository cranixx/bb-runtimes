with System;
use System;
with Interfaces.STM32; use Interfaces.STM32;
with Interfaces.STM32.GPIO; use Interfaces.STM32.GPIO;
with Interfaces.STM32.RCC; use Interfaces.STM32.RCC;

procedure led_on
is
--   RCC_APB2ENR: UInt32;
   RCC_APB2ENR : APB2ENR_Register;
	 GPIOA : GPIO_Peripheral;
   for RCC_APB2ENR'Address    use System'To_Address (16#4002_1018#);
   for GPIOA'Address use System'To_address(16#4001_0800#);

begin
 --  RCC_APB2ENR:= RCC_APB2ENR or 2#1100#;
   RCC_APB2ENR.IOPAEN := 1;
   GPIOA.CRL.CNF5 := 2#00#;
   GPIOA.CRL.MODE5 := 2#11#;

    GPIOA.ODR.ODR.Arr(5) := 1;
	 loop
		 null;
	 end loop;
end led_on;

