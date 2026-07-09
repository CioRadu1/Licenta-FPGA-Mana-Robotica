library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ad7124_ctrl is
	port (
		clk         : in  std_logic;
		rst         : in  std_logic;
		tick_20ms   : in  std_logic;

		spi_start   : out std_logic;
		spi_tx_data : out std_logic_vector(7 downto 0);
		spi_rx_data : in  std_logic_vector(7 downto 0);
		spi_busy    : in  std_logic;
		spi_done    : in  std_logic;
		spi_cs_n    : out std_logic;

		meas_angles : out std_logic_vector(63 downto 0);
		meas_valid  : out std_logic;
		config_done : out std_logic;

		dbg_channels_read : out std_logic_vector(7 downto 0);
		dbg_status        : out std_logic_vector(7 downto 0);

		dbg_id            : out std_logic_vector(7 downto 0)
	);
end entity;

architecture rtl of ad7124_ctrl is

	type main_state_t is (
		S_RESET_SEND, S_RESET_WAIT, S_RESET_DELAY,
		S_ID_CMD, S_ID_CMD_WAIT, S_ID_READ, S_ID_CAP, S_ID_GAP,
		S_INIT_CFG, S_INIT_SEND_CMD, S_INIT_SEND_DATA, S_INIT_WAIT, S_INIT_GAP,
		S_READ_POLL, S_READ_CMD, S_READ_DATA, S_READ_STATUS, S_READ_STORE,
		S_READ_GAP
	);
	signal state : main_state_t := S_RESET_SEND;

	signal reset_cnt : unsigned(2 downto 0) := (others => '0');

	signal delay_cnt : unsigned(18 downto 0) := (others => '0');
	constant DELAY_4MS : unsigned(18 downto 0) := to_unsigned(399999, 19);

	signal gap_cnt : unsigned(8 downto 0) := (others => '0');
	constant GAP_MAX : unsigned(8 downto 0) := to_unsigned(199, 9);

	type init_entry_t is record
		addr     : std_logic_vector(5 downto 0);
		data_len : unsigned(1 downto 0);
		data     : std_logic_vector(23 downto 0);
	end record;
	type init_array_t is array (0 to 11) of init_entry_t;

	constant INIT_SEQ : init_array_t := (

		0  => (addr => "000001", data_len => "01", data => x"0005C8"),

		1  => (addr => "011001", data_len => "01", data => x"000070"),

		2  => (addr => "100001", data_len => "10", data => x"060030"),

		3  => (addr => "001001", data_len => "01", data => x"008011"),

		4  => (addr => "001010", data_len => "01", data => x"008031"),

		5  => (addr => "001011", data_len => "01", data => x"008051"),

		6  => (addr => "001100", data_len => "01", data => x"008071"),

		7  => (addr => "001101", data_len => "01", data => x"008091"),

		8  => (addr => "001110", data_len => "01", data => x"0080B1"),

		9  => (addr => "001111", data_len => "01", data => x"0080D1"),

		10 => (addr => "010000", data_len => "01", data => x"0080F1"),

		11 => (addr => "000001", data_len => "01", data => x"0005C0")
	);

	signal init_idx    : unsigned(3 downto 0) := (others => '0');
	signal byte_idx    : unsigned(1 downto 0) := (others => '0');
	signal cfg_done_r  : std_logic := '0';

	signal read_byte_cnt : unsigned(1 downto 0) := (others => '0');
	signal adc_raw       : std_logic_vector(23 downto 0) := (others => '0');
	signal status_byte   : std_logic_vector(7 downto 0) := (others => '0');
	signal channels_read : std_logic_vector(7 downto 0) := (others => '0');

	type angle_array_t is array (0 to 7) of std_logic_vector(7 downto 0);
	signal angles : angle_array_t := (others => (others => '0'));

	signal cs_held_low : std_logic := '1';
	signal id_reg      : std_logic_vector(7 downto 0) := (others => '0');

begin

	config_done <= cfg_done_r;

	dbg_channels_read <= channels_read;

	dbg_status <= status_byte;

	dbg_id <= id_reg;

	meas_angles(63 downto 56) <= angles(0);
	meas_angles(55 downto 48) <= angles(1);
	meas_angles(47 downto 40) <= angles(2);
	meas_angles(39 downto 32) <= angles(3);
	meas_angles(31 downto 24) <= angles(4);
	meas_angles(23 downto 16) <= angles(5);
	meas_angles(15 downto  8) <= angles(6);
	meas_angles( 7 downto  0) <= angles(7);

	spi_cs_n <= '0' when cs_held_low = '0' else '1';

	process(clk)
		variable adc_val    : unsigned(23 downto 0);
		variable angle_calc : unsigned(31 downto 0);
		variable ch_num     : integer range 0 to 15;
	begin
		if rising_edge(clk) then
			spi_start  <= '0';
			meas_valid <= '0';

			if rst = '1' then
				state        <= S_RESET_SEND;
				reset_cnt    <= (others => '0');
				cfg_done_r   <= '0';
				cs_held_low  <= '1';
				channels_read <= (others => '0');
			else
				case state is

					when S_RESET_SEND =>
						cs_held_low <= '0';
						if spi_busy = '0' then
							spi_tx_data <= x"FF";
							spi_start   <= '1';
							state       <= S_RESET_WAIT;
						end if;

					when S_RESET_WAIT =>
						if spi_done = '1' then
							if reset_cnt = 7 then
								state     <= S_RESET_DELAY;
								delay_cnt <= (others => '0');
								cs_held_low <= '1';
							else
								reset_cnt <= reset_cnt + 1;
								state     <= S_RESET_SEND;
							end if;
						end if;

					when S_RESET_DELAY =>
						if delay_cnt = DELAY_4MS then
							state <= S_ID_CMD;
						else
							delay_cnt <= delay_cnt + 1;
						end if;

					when S_ID_CMD =>
						cs_held_low <= '0';
						if spi_busy = '0' then
							spi_tx_data <= x"45";
							spi_start   <= '1';
							state       <= S_ID_CMD_WAIT;
						end if;

					when S_ID_CMD_WAIT =>
						if spi_done = '1' then
							state <= S_ID_READ;
						end if;

					when S_ID_READ =>
						if spi_busy = '0' then
							spi_tx_data <= x"00";
							spi_start   <= '1';
							state       <= S_ID_CAP;
						end if;

					when S_ID_CAP =>
						if spi_done = '1' then
							id_reg      <= spi_rx_data;
							cs_held_low <= '1';
							gap_cnt     <= (others => '0');
							state       <= S_ID_GAP;
						end if;

					when S_ID_GAP =>
						if gap_cnt = GAP_MAX then
							state    <= S_INIT_CFG;
							init_idx <= (others => '0');
						else
							gap_cnt <= gap_cnt + 1;
						end if;

					when S_INIT_CFG =>
						cs_held_low <= '0';
						if spi_busy = '0' then

							spi_tx_data <= "00" & INIT_SEQ(to_integer(init_idx)).addr;
							spi_start   <= '1';
							byte_idx    <= INIT_SEQ(to_integer(init_idx)).data_len;
							state       <= S_INIT_SEND_CMD;
						end if;

					when S_INIT_SEND_CMD =>
						if spi_done = '1' then
							state <= S_INIT_SEND_DATA;
						end if;

					when S_INIT_SEND_DATA =>
						if spi_busy = '0' then

							case byte_idx is
								when "10" =>
									spi_tx_data <= INIT_SEQ(to_integer(init_idx)).data(23 downto 16);
								when "01" =>
									spi_tx_data <= INIT_SEQ(to_integer(init_idx)).data(15 downto 8);
								when others =>
									spi_tx_data <= INIT_SEQ(to_integer(init_idx)).data(7 downto 0);
							end case;
							spi_start <= '1';
							state     <= S_INIT_WAIT;
						end if;

					when S_INIT_WAIT =>
						if spi_done = '1' then
							if byte_idx = 0 then

								cs_held_low <= '1';
								gap_cnt     <= (others => '0');
								state       <= S_INIT_GAP;
							else
								byte_idx <= byte_idx - 1;
								state    <= S_INIT_SEND_DATA;
							end if;
						end if;

					when S_INIT_GAP =>
						if gap_cnt = GAP_MAX then
							if init_idx = 11 then
								cfg_done_r    <= '1';
								channels_read <= (others => '0');
								state         <= S_READ_POLL;
							else
								init_idx <= init_idx + 1;
								state    <= S_INIT_CFG;
							end if;
						else
							gap_cnt <= gap_cnt + 1;
						end if;

					when S_READ_POLL =>
						cs_held_low <= '0';
						if spi_busy = '0' then

							spi_tx_data <= x"42";
							spi_start   <= '1';
							read_byte_cnt <= (others => '0');
							state         <= S_READ_CMD;
						end if;

					when S_READ_CMD =>
						if spi_done = '1' then
							state <= S_READ_DATA;
						end if;

					when S_READ_DATA =>
						if spi_busy = '0' then
							spi_tx_data <= x"00";
							spi_start   <= '1';
							state       <= S_READ_STATUS;
						end if;

					when S_READ_STATUS =>
						if spi_done = '1' then
							case read_byte_cnt is
								when "00" =>
									adc_raw(23 downto 16) <= spi_rx_data;
								when "01" =>
									adc_raw(15 downto 8) <= spi_rx_data;
								when "10" =>
									adc_raw(7 downto 0) <= spi_rx_data;
								when others =>
									status_byte <= spi_rx_data;
							end case;

							if read_byte_cnt = 3 then
								state <= S_READ_STORE;
							else
								read_byte_cnt <= read_byte_cnt + 1;
								state         <= S_READ_DATA;
							end if;
						end if;

					when S_READ_STORE =>
						adc_val    := unsigned(adc_raw);

						angle_calc := resize(adc_val * to_unsigned(180, 8), 32);
						ch_num     := to_integer(unsigned(status_byte(3 downto 0)));

						if ch_num < 8 then
							angles(ch_num) <= std_logic_vector(angle_calc(31 downto 24));
							channels_read(ch_num) <= '1';
						end if;

						meas_valid  <= '1';

						cs_held_low <= '1';
						gap_cnt     <= (others => '0');
						state       <= S_READ_GAP;

					when S_READ_GAP =>
						if gap_cnt = GAP_MAX then
							state <= S_READ_POLL;
						else
							gap_cnt <= gap_cnt + 1;
						end if;

				end case;
			end if;
		end if;
	end process;

end architecture;
