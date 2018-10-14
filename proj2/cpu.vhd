-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2013 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Zdenek Vasicek <vasicek AT fit.vutbr.cz>
-- Upravil: Michal Melichar - xmelic17

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (1) / zapis (0)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

 -- zde dopiste potrebne deklarace signalu
 signal PC_registr: std_logic_vector(11 downto 0);
 signal PC_decrement: std_logic;
 signal PC_increment: std_logic;
 signal PC_ABus: std_logic;
 
 signal PTR_registr: std_logic_vector(9 downto 0);
 signal PTR_decrement: std_logic;
 signal PTR_increment: std_logic;
 signal PTR_ABus: std_logic;

 type instruction_type is (incPTR, decPTR, incVAL, decVAL, whileL, whileR, printfVAL, readVAL, halt, skip); 
 signal ireg_reg: std_logic_vector(7 downto 0);
 signal ireg_ld: std_logic; 
 signal ireg_dec: instruction_type;
 
 type fsm_state is (sidle, sfetch0, sfetch1, sdecode, sincPTR, sdecPTR, sincVAL, sincVAL2, sdecVAL, sdecVAL2, swhileL, swhileL2, swhileL3, swhileR, swhileR2, swhileR3, swhileR4, sprintfVAL, sprintfVAL2, sreadVAL, sreadVAL2, shalt, sskip);
 signal present_state: fsm_state;
 signal next_state: fsm_state;

 signal SEL: std_logic_vector(1 downto 0);
begin
--------------
-- Registr PC
--------------
program_counter: process (RESET, CLK)
begin
	if(RESET='1') then -- resetovani, pokud je nastaven RESET
		PC_registr <= (others => '0');
		
	elsif((CLK'event) and (CLK = '1')) then -- nabezna hrana
		if((PC_decrement = '1') and (PC_increment = '0')) then -- dekrementace PC registru
			PC_registr <= PC_registr - 1;
		end if;
		if((PC_decrement = '0') and (PC_increment = '1')) then -- incrementace PC registru
			PC_registr <= PC_registr + 1;
		end if;
	end if;
end process;

CODE_ADDR <= PC_registr when (PC_ABus = '1')
								else (others => 'Z');
								

-- dopsat registry CNT, RAS


--------
-- PTR
--------
memory_pointer: process (RESET, CLK)
begin
	if(RESET = '1') then -- resetovano, pokud je nastaven reset
		PTR_registr <= (others => '0');
		
	elsif((CLK'event) and (CLK = '1')) then
		if((PTR_decrement = '1') and (PTR_increment = '0')) then -- dekrementace PTR
			PTR_registr <= PTR_registr - 1;
		end if;
		if((PTR_decrement = '0') and (PTR_increment = '1')) then -- incrementace PTR
			PTR_registr <= PTR_registr + 1;
		end if;
	end if;
end process;

DATA_ADDR <= PTR_registr when (PTR_ABus = '1')
								 else (others => 'Z');
								 
								 
----------------------
-- Registr instrukci
----------------------
instruktion_registr: process (RESET, CLK)
begin
	if(RESET = '1') then
		ireg_reg <= (others => '0');
	
	elsif((CLK'event) and (CLK = '1')) then
		if(ireg_ld = '1') then
			ireg_reg <= CODE_DATA;
		end if;
	end if;
end process;


------------------------
-- Instruction decoder
------------------------
instruction_decoder: process (ireg_reg)
begin
		case ireg_reg is
			when X"3E" => ireg_dec <= incPTR;    -- ">"
			when X"3C" => ireg_dec <= decPTR;    -- "<"
			when X"2B" => ireg_dec <= incVAL;    -- "+" 
			when X"2D" => ireg_dec <= decVAL;    -- "-"
			when X"5B" => ireg_dec <= whileL;    -- "["
			when X"5D" => ireg_dec <= whileR;    -- "]"
			when X"2E" => ireg_dec <= printfVAL; --"."
			when X"2C" => ireg_dec <= readVAL;   --","
			when X"00" => ireg_dec <= halt;      --"null"
			when others => ireg_dec <= skip; -- pro vsechny ostatni pripady
		end case;
end process;

----------
-- MUX
----------
multiplexor: process(IN_DATA, SEL, DATA_RDATA)
begin
	case SEL is
		when "00" => DATA_WDATA <= DATA_RDATA + '1';
		when "01" => DATA_WDATA <= DATA_RDATA - '1';
		when "10" => DATA_WDATA <= IN_DATA;
		when others => DATA_WDATA <= (others => '0');
	end case;
end process;


---------------------
-- FSM present state
---------------------
fsm_pstate: process (RESET, CLK, EN)
begin
	if(RESET = '1') then
		present_state <= sidle;
		
	elsif ((CLK'event) and (CLK = '1')) then
		if(EN = '1') then
		 present_state <= next_state;
		end if;
	end if;
end process;


-------------------------------
-- FSM next state (Moore FSM)
-------------------------------
fsm_nstate: process (present_state, ireg_dec, OUT_BUSY)
begin
	next_state <= sidle;
	
	-- INIT
	CODE_EN <= '0';
	DATA_EN <= '0';
	OUT_WE <= '0';
	PC_decrement <= '0';
   PC_increment <= '0';
   PC_ABus <= '0';
	PTR_decrement <= '0';
   PTR_increment <= '0';
   PTR_ABus <= '0';
	ireg_ld <= '0';
	
	case present_state is
		-- IDLE
		when sidle =>
			next_state <= sfetch0;
			
		-- INSTRUCTION FETCH
		when sfetch0 =>
			next_state <= sfetch1;
			PC_ABus <= '1';
			CODE_EN <= '1';
			
		when sfetch1 => -- NACTENI DO REGISTU INTRUKCI
			next_state <= sdecode;
			ireg_ld <= '1';
			
		-- DEKODOVANI INSTRUKCE
		when sdecode =>
			case ireg_dec is
				when incPTR =>
					next_state <= sincPTR;
				when decPTR =>
					next_state <= sdecPTR;
				when incVAL =>
					next_state <= sincVAL;
				when decVAL =>
					next_state <= sdecVAL;
				when whileL =>
					next_state <= swhileL;
				when whileR =>
					next_state <= swhileR;
				when printfVAL =>
					next_state <= sprintfVAL;
				when readVAL =>
					next_state <= sreadVAL;
				when halt =>
					next_state <= shalt;
				when skip =>
					next_state <= sskip;
			end case;
					
				 
	   -- INCREMENT PTR
		when sincPTR =>
			next_state <= sfetch0;
			PTR_decrement <= '0';
         PTR_increment <= '1';
			PC_decrement <= '0';
			PC_increment <= '1';
			PTR_ABus <= '1';
			
		-- DECREMENT PTR
		when sdecPTR =>
			next_state <= sfetch0;
			PTR_decrement <= '1';
         PTR_increment <= '0';
			PC_decrement <= '0';
			PC_increment <= '1';
			PTR_ABus <= '1';
			
		-- INCREMENT VAL
		when sincVAL => -- prvni faze
			next_state <= sincVAL2;
			DATA_EN <= '1';
			PTR_ABus <= '1';
			DATA_RDWR <= '1';
			
		when sincVAL2 => -- druha faze
			next_state <= sfetch0;
			PTR_ABus <= '1';
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			SEL <= "00";
			PC_decrement <= '0';
			PC_increment <= '1';	

		-- DECREMENT VAL
		when sdecVAL => -- prvni faze
			next_state <= sdecVAL2;
			DATA_EN <= '1';
			PTR_ABus <= '1';
			DATA_RDWR <= '1';
			
		when sdecVAL2 => -- druha faze
			next_state <= sfetch0;
			PTR_ABus <= '1';
			DATA_EN <= '1';
			DATA_RDWR <= '0';
			SEL <= "01";
			PC_decrement <= '0';
			PC_increment <= '1';						
		
		-- PRINTF
		when sprintfVAL =>
			next_state <= sprintfVAL2;
			DATA_EN <= '1';
			PTR_ABus <= '1';
			DATA_RDWR <= '1';
			
		when sprintfVAL2 =>
			if(OUT_BUSY = '0') then
				OUT_WE <= '1';
				OUT_DATA <= DATA_RDATA;
				PC_decrement <= '0';
			   PC_increment <= '1';				
			   next_state <= sfetch0;	
			else next_state <= sprintfVAL2;
			end if;
			
		-- READ
		when sreadVAL =>
			IN_REQ <= '1';
			next_state <= sreadVAL2;
			
		when sreadVAL2 =>
			if(IN_VLD = '1') then
				DATA_EN <= '1';
				PTR_ABus <= '1';
				DATA_RDWR <= '0';
				SEL <= "10";
				IN_REQ <= '0';
				PC_decrement <= '0';
			   PC_increment <= '1';	
				next_state <= sfetch0;
			else next_state <= sreadVAL2;
			end if;				
		
		-- HALT 
		when shalt =>
			next_state <= shalt;
			
		-- SKIP
		when sskip =>
			next_state <= sfetch0;
			PC_decrement <= '0';
			PC_increment <= '1';
			
			
	   -- START WHILE 
		when swhileL =>
			PC_decrement <= '0';
			PC_increment <= '1';
			DATA_EN <= '1';
			PTR_ABus <= '1';
			DATA_RDWR <= '1';
			next_state <= swhileL2;
			
		when swhileL2 =>
			if(DATA_RDATA = "00000000") then
				next_state <= swhileL3;
			else
				next_state <= sfetch0;
			end if;
		
		when swhileL3 =>
			if(ireg_reg = "01011101") then
			   ireg_ld <= '1';
				PC_decrement <= '0';
				PC_increment <= '1';
				next_state <= swhileL3;
			else
				next_state <= sfetch0;
			end if;
		
		
		-- END WHILE
		-- dopsat jeste
		when swhileR =>
			DATA_EN <= '1';
			PTR_ABus <= '1';
			DATA_RDWR <= '1';
			next_state <= swhileR2;
			
		when swhileR2 =>
			if(DATA_RDATA /= "00000000") then
				next_state <= swhileR3;
			else
				PC_decrement <= '0';
			   PC_increment <= '1';
				next_state <= sfetch0;
			end if;
		
		when swhileR3 =>
			next_state <= swhileR4;
			ireg_ld <= '1';
			PC_ABus <= '1';
			CODE_EN <= '1';
		
		when swhileR4 =>
			PC_decrement <= '1';
			PC_increment <= '0';
			if(ireg_reg /= "01011011") then
				next_state <= swhileR3;
			else
				PC_decrement <= '0';
				PC_increment <= '1';
				next_state <= sfetch0;
			end if;
			

	end case;
end process;
end behavioral;

