library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; 
use ieee.numeric_std.all;
use work.all;

entity UART_MULTI is

	port(
      --80 y 81 no sirven
		CLK : in std_logic;  -- PIN_17
		
		lee, esc: in std_logic;--Guarda y muestra datos de la memoria RAM
	   dir: in std_logic_vector(2 downto 0);--Direccion donde se guardan los datos
		
		BTN  : in std_logic;     -- 1 button para transimitir datos
		BTN2: in std_LOGIC;--INDICA QUE SE HAGA LA OPERACION
		display: out std_logic_vector(7 downto 0);--Numero de display
		salida: out std_logic_vector(6 downto 0);--SEGMENTOS DEL DISPLAY
		DATO : in std_logic_vector( 7 downto 0 ); --Los 8 bits que se transmitiran

		RX_LINE : in std_logic;  -- PIN_40
		TX_LINE : out std_logic  -- PIN_42 
	);

end entity;

architecture arch of UART_MULTI is

	subtype byte is std_logic_vector(7 downto 0);
	type tm is array(0 to 1024) of byte; --matriz
	signal mem: tm;
	
	signal x, y, z : std_logic_vector(31 downto 0);
	signal seleccion: STD_LOGIC_VECTOR(2 downto 0):="000";
	signal mostrar: STD_LOGIC_VECTOR(3 downto 0);
	
	signal dataValid_TX  : std_logic := '0';
	signal data_TX       : std_logic_vector( 7 downto 0 ) := ( others => '0' );
	signal active_TX     : std_logic;
	signal done_TX       : std_logic;

	signal dataValid_RX : std_logic;
	signal data_RX      : std_logic_vector( 7 downto 0 ) := ( others => '1' ); 
	
	component UART_TX is 

		--generic (
		--
		--	g_CLKS_PER_BIT : integer
		--);

		port(

			CLK           : in std_logic;
			TX_DATA_VALID : in std_logic;  -- Iniciar transmision
			TX_DATA       : in std_logic_vector( 7 downto 0 );  -- buffer
			TX_LINE       : out std_logic;
			TX_ACTIVE     : out std_logic;
			TX_DONE       : out std_logic
		);

	end component;

	component UART_RX is

		--generic (
		--
		--	g_CLKS_PER_BIT : integer;
		--	g_CLKS_PER_HALF_BIT : integer
		--);	

		port(

			CLK           : in std_logic;
			RX_LINE       : in std_logic;
			RX_DATA_VALID : out std_logic;
			RX_DATA       : out std_logic_vector( 7 downto 0 )  -- buffer
		);

	end component;

begin

-- Instantiate UART transmitter
	UART_TX_instance : TX

		--generic map (
		--
		--	5208  -- CLKS_PER_BIT 50Mhz/9600bps
		--)

		port map (

			CLK,           -- in
			dataValid_TX,  -- in
			data_TX,       -- in
			TX_LINE,       -- out
			active_TX,     -- out
			done_TX        -- out
		);

	-- Instanciar Uart Rx
	UART_RX_instance : RX

		--generic map (
		--
		--	5208, -- CLKS_PER_BIT
		--	2604  -- CLKS_PER_HALF_BIT
		--)

		port map (

			CLK,           -- in
			RX_LINE,       -- in
			dataValid_RX,  -- out
			data_RX        -- out
		);

	process( CLK, x, y, z )
		variable ind: unsigned(2 downto 0);
		variable x_mantisa : STD_LOGIC_VECTOR (22 downto 0);
		variable x_exponente : STD_LOGIC_VECTOR (7 downto 0);
		variable x_signo : STD_LOGIC;
		variable y_mantisa : STD_LOGIC_VECTOR (22 downto 0);
		variable y_exponente : STD_LOGIC_VECTOR (7 downto 0);
		variable y_signo : STD_LOGIC;
		variable z_mantisa : STD_LOGIC_VECTOR (22 downto 0);
		variable z_exponente : STD_LOGIC_VECTOR (7 downto 0);
		variable z_signo : STD_LOGIC;
		variable aux : STD_LOGIC; --suma exponene
		variable aux2 : STD_LOGIC_VECTOR (47 downto 0);--Resultado multiplicacion
		variable exponente_suma : STD_LOGIC_VECTOR (8 downto 0);
		
	begin

	if rising_edge (clk) then
	
	-- Transmit if button pressed and transmitter not busy

			if BTN = '0' and active_TX = '0' then

				dataValid_TX <= '1';

				data_TX <= DATO(7 downto 0);  

			else
				
				dataValid_TX <= '0';

			end if;
	
			ind:=unsigned(dir);		
			if lee='1' then
				case dir is
				when"000"=>  ind:=unsigned(dir); x(31 downto 24)<=mem(to_integer(ind));
				when"001"=>  ind:=unsigned(dir); x(23 downto 16)<=mem(to_integer(ind));
				when"010"=>  ind:=unsigned(dir); x(15 downto 8)<=mem(to_integer(ind));
				when"011"=>  ind:=unsigned(dir); x(7 downto 0)<=mem(to_integer(ind));
				when"100"=>  ind:=unsigned(dir); y(31 downto 24)<=mem(to_integer(ind));
				when"101"=>  ind:=unsigned(dir); y(23 downto 16)<=mem(to_integer(ind));
				when"110"=>  ind:=unsigned(dir); y(15 downto 8)<=mem(to_integer(ind));
				when others => ind:=unsigned(dir); y(7 downto 0)<=mem(to_integer(ind));
			end case;	
				
			elsif esc='1' then
				mem(to_integer(ind))<=data_RX(7 downto 0 );
			end if;
			
			if BTN2='0' THEN
				x_mantisa := x(22 downto 0);
				x_exponente := x(30 downto 23);
				x_signo := x(31);
				y_mantisa := y (22 downto 0);
				y_exponente := y(30 downto 23);
				y_signo := y(31);
				
			--Caaso NAN Inf*0
				if ((x_exponente=255 and y_exponente=0) or (x_exponente=0 and y_exponente=255) 
				or (x_exponente=255 and x_mantisa="11111111111111111111111") 
				or (y_exponente=255 and y_mantisa="11111111111111111111111")) then 
					z_exponente := "11111111";
					z_mantisa := (others => '1');
					z_signo := x_signo xor y_signo;		
					
				else
					-- Caso inf*x o inf*y
					if (x_exponente=255 or y_exponente=255) then 
						z_exponente := "11111111";
						z_mantisa := (others => '0');
						z_signo := x_signo xor y_signo;
						
							-- Caso 0*x o 0*y
					elsif (x_exponente=0 or y_exponente=0) then 
						z_exponente := (others => '0');
						z_mantisa := (others => '0');
						z_signo := '0';
					else
						
						aux2 := ('1' & x_mantisa) * ('1' & y_mantisa);
						-- Se concatena el bit implicito
						if (aux2(47)='1') then --si aux2=1 desplazar a la izquierda y sumar uno al exponente
							z_mantisa := aux2(46 downto 24); -- TRUNCADO
							aux := '1';
						else
							z_mantisa := aux2(45 downto 23); -- TRUNCADO
							aux := '0';
						end if;
						
						-- Calcular exponente
						exponente_suma := ('0' & x_exponente) + ('0' & y_exponente) + aux - 127; 
						--Se Concatena un 0 para overflow o underflow y resta 127 de sesgo
						
						if (exponente_suma(8)='1') then 
							if (exponente_suma(7)='0') then -- overflow
								z_exponente := "11111111";
								z_mantisa := (others => '0');
								z_signo := x_signo xor y_signo;
							else 									-- underflow
								z_exponente := (others => '0');
								z_mantisa := (others => '0');
								z_signo := '0';
							end if;
						else								  		 -- Ok
							z_exponente := exponente_suma(7 downto 0);
							z_signo := x_signo xor y_signo;
						end if;
					end if;
			 end if;		
			-- Guardamos resultado
			z(22 downto 0) <= z_mantisa;
			z(30 downto 23) <= z_exponente;
			z(31) <= z_signo;	
	
			end if;
	end if;
	end process;
	
	process(clk,seleccion, z) ---Barrido de los 8 displays de 7 segmentos
	
	variable contador: integer range 0 to 500000:=0;

begin 
	if rising_edge (clk) then
		if contador=80000 then --50000
			seleccion <= seleccion+1;
			contador:=0;
		else
			contador:= contador+1;
		end if;
	end if;

case seleccion is
	when"000"=> display<=not"10000000"; mostrar <= z(3 downto 0);
	when"001"=> display<=not"01000000"; mostrar<= z(7 downto 4);
	when"010"=> display<=not"00100000"; mostrar<= z(11 downto 8);
	when"011"=> display<=not"00010000"; mostrar<= z(15 downto 12);
	when"100"=> display<=not"00001000"; mostrar<= z(19 downto 16);
	when"101"=> display<=not"00000100"; mostrar<= z(23 downto 20);
	when"110"=> display<=not"00000010"; mostrar<= z(27 downto 24);
	when others => display<=not"00000001"; mostrar <= z(31 downto 28);
end case;
end process;

with mostrar select --------Indica que numeor muestra el display de 7 segmentos
salida <="0111111" when "0000",--0
     "0000110" when "0001",--1
	  "1011011" when "0010",--2
     "1001111" when "0011",--3
	  "1100110" when "0100",--4
	  "1101101" when "0101",--5
	  "1111101" when "0110",--6
	  "0000111" when "0111",--7
	  "1111111" when "1000",--8
	  "1100111" when "1001",--9
	  "1110111" when "1010",--A
     "1111100" when "1011",--B
     "0111001" when "1100",--C
     "1011110" when "1101",--D
     "1111001" when "1110",--E
     "1110001" when others;--F	

end architecture;