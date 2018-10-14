--Michal Melichar, xmelic17
--25.11.2014

--vlozeni knihoven
library IEEE;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_1164.all;

--definice vstupu a vystupu
entity ledc8x8 is
	port(
		RESET: in std_logic;
		SMCLK: in std_logic;
		ROW: out std_logic_vector (0 to 7);
		LED: out std_logic_vector (0 to 7)
	);
end entity ledc8x8;


architecture behav of ledc8x8 is
	signal ce: STD_LOGIC;
	signal switch: STD_LOGIC;
	signal ctrl_cnt: STD_LOGIC_VECTOR (21 downto 0) := (others => '0');	
	signal row_cnt: STD_LOGIC_VECTOR (0 to 7) := "10000000";
	signal led_blik: STD_LOGIC_VECTOR (0 to 7);
	
begin


--deleni kmitoctu
process (RESET, SMCLK)
begin
	if RESET = '1' then
		ctrl_cnt <= (others => '0');
	elsif SMCLK'event and SMCLK = '1' then
		ctrl_cnt <= ctrl_cnt + 1;
		if ctrl_cnt(7 downto 0) = "11111111" then 
			ce <= '1';
		else ce <= '0';
		end if;
	end if;
	
	switch <= ctrl_cnt(21);
end process;


--aktivace jednotlivych radku
process (RESET, SMCLK)
begin
	if RESET = '1'  then
		row_cnt <= "10000000";--nastaveni prvniho radku
	
	elsif SMCLK'event and SMCLK = '1' then --aktivace dalsich radku
		if ce = '1' then
			case row_cnt is 
				when "00000001" => row_cnt <= "10000000";
				when "00000010" => row_cnt <= "00000001";
				when "00000100" => row_cnt <= "00000010";
				when "00001000" => row_cnt <= "00000100";
				when "00010000" => row_cnt <= "00001000";
				when "00100000" => row_cnt <= "00010000";
				when "01000000" => row_cnt <= "00100000";
				when "10000000" => row_cnt <= "01000000";
				when others => null;
			end case;
		end if;
	end if;		
end process;


--zobrazeni pismen
process (row_cnt)
begin	
	case row_cnt is         
		when "10000000" => led_blik <= "01111101";
		when "01000000" => led_blik <= "00111001";
		when "00100000" => led_blik <= "01010101";
		when "00010000" => led_blik <= "01101101";
		when "00001000" => led_blik <= "00111001";
		when "00000100" => led_blik <= "00010001";
		when "00000010" => led_blik <= "00101001";
		when "00000001" => led_blik <= "00111001";
		when others => led_blik <="11111111";
	end case;
end process;


--blikani diod
process(row_cnt)
begin
	ROW <= row_cnt;
	if switch = '1' then
		LED <= led_blik;
	else LED <= "11111111";
	end if;
end process;

end architecture behav;	