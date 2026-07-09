library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity demo_rom is
	port (
		clk        : in  std_logic;
		rst        : in  std_logic;
		enable     : in  std_logic;
		tick_20ms  : in  std_logic;
		angles_out : out std_logic_vector(63 downto 0)
	);
end entity;

architecture rtl of demo_rom is

	type keyframe_t is record
		angles : std_logic_vector(63 downto 0);
		hold   : unsigned(7 downto 0);
	end record;

	type rom_t is array (0 to 31) of keyframe_t;

	constant ROM : rom_t := (

		0  => (angles => x"B4B4B4B45A5A5A5A", hold => to_unsigned(50, 8)),

		1  => (angles => x"00000000005A5A5A", hold => to_unsigned(50, 8)),

		2  => (angles => x"B4B4B4B45A5A5A5A", hold => to_unsigned(50, 8)),

		3  => (angles => x"00000000005A5A5A", hold => to_unsigned(50, 8)),

		4  => (angles => x"B4B4B4B45A5A005A", hold => to_unsigned(25, 8)),

		5  => (angles => x"B4B4B4B45A5AB45A", hold => to_unsigned(25, 8)),

		6  => (angles => x"B4B4B4B45A5A005A", hold => to_unsigned(25, 8)),

		7  => (angles => x"B4B4B4B45A5AB45A", hold => to_unsigned(25, 8)),

		8  => (angles => x"B4B4B4B45A5A5A5A", hold => to_unsigned(25, 8)),

		9  => (angles => x"00B4B4B45A5A5A5A", hold => to_unsigned(30, 8)),

		10 => (angles => x"B400B4B45A5A5A5A", hold => to_unsigned(30, 8)),

		11 => (angles => x"B4B400B45A5A5A5A", hold => to_unsigned(30, 8)),

		12 => (angles => x"B4B4B4005A5A5A5A", hold => to_unsigned(30, 8)),

		13 => (angles => x"B4B4B4B45A5A5A5A", hold => to_unsigned(30, 8)),

		14 => (angles => x"000000005AB45A5A", hold => to_unsigned(75, 8)),

		15 => (angles => x"B4B4B4B45A5A5A5A", hold => to_unsigned(50, 8)),

		16 => (angles => x"000000B45A005A5A", hold => to_unsigned(75, 8)),

		17 => (angles => x"B4B4B4B45A5A5A5A", hold => to_unsigned(50, 8)),

		18 => (angles => x"B4B4B4B45A5A5A00", hold => to_unsigned(50, 8)),

		19 => (angles => x"B4B4B4B45A5A5AB4", hold => to_unsigned(50, 8)),

		20 => (angles => x"B4B4B4B45A5A5A5A", hold => to_unsigned(50, 8)),

		21 => (angles => x"B4B4B4B45A5A5A5A", hold => to_unsigned(0, 8)),
		others => (angles => x"5A5A5A5A5A5A5A5A", hold => to_unsigned(0, 8))
	);

	constant LAST_KF : integer := 20;

	signal kf_index     : unsigned(4 downto 0) := (others => '0');
	signal hold_counter : unsigned(7 downto 0) := (others => '0');
	signal current_kf   : keyframe_t;
begin

	current_kf <= ROM(to_integer(kf_index));

	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' or enable = '0' then
				kf_index     <= (others => '0');
				hold_counter <= (others => '0');
			elsif tick_20ms = '1' and enable = '1' then
				if hold_counter >= current_kf.hold then
					hold_counter <= (others => '0');
					if kf_index >= LAST_KF then
						kf_index <= (others => '0');
					else
						kf_index <= kf_index + 1;
					end if;
				else
					hold_counter <= hold_counter + 1;
				end if;
			end if;
		end if;
	end process;

	angles_out <= current_kf.angles when enable = '1'
	              else (others => '0');

end architecture;
