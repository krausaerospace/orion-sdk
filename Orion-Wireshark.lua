-------------------------------------------------------------------------------
-- Orion protocol dissector for Wireshark
--
-- To use, place in the "User plugins" folder. Orion packets can be filtered
--   as follows:
--
--  * orion
--      This filter shows all frames which contain Orion packets
--  * orion.id == 0x01
--      Use this form to show only frames which contain orion packets with ID
--      0x01 (ORION_PKT_CMD)
--  * orion.length == 7
--      Use this form to show only frames which contain Orion packets with
--      a data payload length of 7
--
-- NOTES:
--  * This is not a complete parser - unimplemented packets will just show the
--      type ID and raw hex dump of the packet data
--  * Checksums are not validated by this module. This means that any frame on
--      TCP port 8747 or UDP port 8748 which *starts* with the Orion packet
--      sync bytes (0xd0 0x0d) will be marked as Orion packets
--
-------------------------------------------------------------------------------

-- Declare the Orion Protocol
orion = Proto("orion","Orion Protocol")

-- the new fields that contain the extracted data (one in string form, one in hex)
orion_id = ProtoField.new("Packet Type ID", "orion.id", ftypes.UINT8)
orion_len = ProtoField.new("Data Length", "orion.length", ftypes.UINT8)

-- register the new fields into our fake protocol
orion.fields = { orion_id, orion_len }

function get_mode_string(mode)

	local mode_str = "Unknown Mode 0x" .. mode

	if mode == 0 then mode_str = "Disabled"
	elseif mode == 16 then mode_str = "Rate"
	elseif mode == 32 then mode_str = "FFC Auto"
	elseif mode == 33 then mode_str = "FFC Manual"
	elseif mode == 48 then mode_str = "Scene"
	elseif mode == 49 then mode_str = "Track"
	elseif mode == 64 then mode_str = "Calibration"
	elseif mode == 80 then mode_str = "Position"
	elseif mode == 96 then mode_str = "Geopoint"
	elseif mode == 102 then mode_str = "Path"
	elseif mode == 103 then mode_str = "Look Down"
	end

	return mode_str

end

function get_gps_string(gps_source)

    local gps_string = "Other"
    if gps_source == 0 then gps_string = "External"
	elseif gps_source == 1 then gps_string = "U-Blox"
	elseif gps_source == 2 then gps_string = "Mavlink"
	elseif gps_source == 3 then gps_string = "NMEA"
	elseif gps_source == 4 then gps_string = "Novatel"
	elseif gps_source == 5 then gps_string = "Piccolo"
	end

	return gps_string

end

function get_board_string(board)

	local board_str = "Unknown"

	if board == 1 then board_str = "Clevis"
	elseif board == 2 then board_str = "INS"
	elseif board == 3 then board_str = "Payload"
	elseif board == 4 then board_str = "Lens Control"
	end

	return board_str

end

function make_subtree(subtree, buffer, name, id, size)
	subtree = subtree:add(orion, buffer(), name)
	subtree:add(orion_id, id)
	subtree:add(orion_len, size)
	return subtree
end

function print_cmd(subtree, buffer, id, size)
	local name =  "Command"
	subtree = make_subtree(subtree, buffer, name, id, size)

	subtree:add(buffer(0,2), "Pan target: " .. math.deg(buffer(0,2):int() / 1000.0))
	subtree:add(buffer(2,2), "Tilt target: " .. math.deg(buffer(2,2):int() / 1000.0))

	local mode = buffer(4,1):uint()

	subtree:add(buffer(4,1), "Mode: " .. get_mode_string(mode))
	subtree:add(buffer(5,1), "Stabilized: " .. buffer(5,1):uint())
	subtree:add(buffer(6,1), "Impulse Time: " .. buffer(6,1):uint() / 10.0)

	return name
end

function print_diagnostics(subtree, buffer, id, size)
	local name = "Diagnostics"
	subtree = make_subtree(subtree, buffer, name, id, size)

	subtree:add(buffer(12,1), "Crown Temp: " .. buffer(12,1):uint() .. "º")
	subtree:add(buffer(13,1), "SLA Temp: " .. buffer(13,1):uint() .. "º")
	subtree:add(buffer(14,1), "Gyro Temp: " .. buffer(14,1):uint() .. "º")

	local v24 = subtree:add(buffer, "24 Vdc Statistics")
	v24:add(buffer(0,2), "Voltage: " .. buffer(0,2):uint() / 1000.0)
	v24:add(buffer(6,2), "Current: " .. buffer(6,2):uint() / 1000.0)
	v24:add(buffer(16,2), "RMS Voltage: " .. buffer(16,2):uint() / 1000.0)
	v24:add(buffer(22,2), "RMS Current: " .. buffer(22,2):uint() / 1000.0)

	local v12 = subtree:add(buffer, "12 Vdc Statistics")
	v12:add(buffer(2,2), "Voltage: " .. buffer(2,2):uint() / 1000.0)
	v12:add(buffer(8,2), "Current: " .. buffer(8,2):uint() / 1000.0)
	v12:add(buffer(18,2), "RMS Voltage: " .. buffer(18,2):uint() / 1000.0)
	v12:add(buffer(24,2), "RMS Current: " .. buffer(24,2):uint() / 1000.0)

	local v33 = subtree:add(buffer, "3.3 Vdc Statistics")
	v33:add(buffer(4,2), "Voltage: " .. buffer(4,2):uint() / 1000.0)
	v33:add(buffer(10,2), "Current: " .. buffer(10,2):uint() / 1000.0)
	v33:add(buffer(20,2), "RMS Voltage: " .. buffer(20,2):uint() / 1000.0)
	v33:add(buffer(26,2), "RMS Current: " .. buffer(26,2):uint() / 1000.0)

	return name
end

function print_sw_diagnostics(subtree, buffer, id, size)
	local board = buffer(0,1):uint()

	local name = get_board_string(board) .. " Board SW Diagnostics"
	subtree = make_subtree(subtree, buffer, name, id, size)

	local j = 4

	for i=1,buffer(1,1):uint() do

		local size = 5 + buffer(j + 4,1):uint() * 6
		local core = subtree:add(buffer(j, size), "Core " .. i - 1 .. " Loading")

		core:add(buffer(j+0,1), "CPU Load: " .. buffer(j+0,1):uint() / 2.55 .. "%")
		core:add(buffer(j+1,1), "Heap Load: " .. buffer(j+1,1):uint() / 2.55 .. "%")
		core:add(buffer(j+2,1), "Stack Load: " .. buffer(j+2,1):uint() / 2.55 .. "%")

		for k=0,buffer(j+4,1):uint()-1 do
			local thread = core:add(buffer(j + 5 + k * 6, 6), "Thread " .. k .. " Loading")
			local load = buffer(j + 5 + k * 6 + 0, 1):uint() / 255.0
			local iter = buffer(j + 5 + k * 6 + 4, 1):uint()

			thread:add(buffer(j + 5 + k * 6 + 0, 1), "CPU Load: " .. buffer(j + 5 + k * 6 + 0, 1):uint() / 2.55 .. "%")
			thread:add(buffer(j + 5 + k * 6 + 1, 1), "Heap Load: " .. buffer(j + 5 + k * 6 + 1, 1):uint() / 2.55 .. "%")
			thread:add(buffer(j + 5 + k * 6 + 2, 1), "Stack Load: " .. buffer(j + 5 + k * 6 + 2, 1):uint() / 2.55 .. "%")
			thread:add(buffer(j + 5 + k * 6 + 3, 1), "WDT Left: " .. buffer(j + 5 + k * 6 + 3, 1):uint() / 2.55 .. "%")
			thread:add(buffer(j + 5 + k * 6 + 4, 1), "Iterations: " .. buffer(j + 5 + k * 6 + 4, 1):uint())

			if iter > 0 and iter < 255 then
				local period = 5.0
				local average_ms = period * load / iter * 1000.0
				local worst = buffer(j + 5 + k * 6 + 5, 1):uint() / 10.0
				thread:add(buffer(j + 5 + k * 6, 6), "Average Time: " .. average_ms .. "ms")
				thread:add(buffer(j + 5 + k * 6 + 5, 1), "Worst Case (" .. worst .. "x): " .. average_ms * worst .. "ms")
			end

		end

		j = j + size
	end

	return name

end	

function print_performance(subtree, buffer, id, size)
	local name = "Performance"
	subtree = make_subtree(subtree, buffer, name, id, size)

	subtree:add(buffer(0,2),  "Pan Quadrature Current Jitter: " .. buffer(0,2):uint() .. " uA")
	subtree:add(buffer(4,2),  "Pan Direct Current Jitter: " .. buffer(4,2):uint() .. " uA")
	subtree:add(buffer(8,2),  "Pan Velocity Jitter: " .. buffer(8,2):uint() .. " mrad/s")
	subtree:add(buffer(12,2), "Pan Position Jitter: " .. buffer(12,2):uint() .. " urad")
	subtree:add(buffer(16,2), "Pan Output Current: " .. buffer(16,2):uint() * 0.001 .. " Amps")
	subtree:add(buffer(2,2),  "Tilt Quadrature Current Jitter: " .. buffer(2,2):uint() .. " uA")
	subtree:add(buffer(6,2),  "Tilt Direct Current Jitter: " .. buffer(6,2):uint() .. " uA")
	subtree:add(buffer(10,2), "Tilt Velocity Jitter: " .. buffer(10,2):uint() .. " mrad/s")
	subtree:add(buffer(14,2), "Tilt Position Jitter: " .. buffer(14,2):uint() .. " urad")
	subtree:add(buffer(18,2), "Tilt Output Current: " .. buffer(18,2):uint() * 0.001 .. " Amps")

	return name
end

function print_gps_data(subtree, buffer, id, size)
	local name = "GPS Data"
	subtree = make_subtree(subtree, buffer, name, id, size)

    local fix_type = bit.band(buffer(0,1):uint(), 127)
	local fix_string = "None"
	local vertical_valid = bit.band(buffer(0,1):uint(), 128) / 128

	if fix_type == 1 then fix_string = "Dead Reckoning"
	elseif fix_type == 2 then fix_string = "2D"
	elseif fix_type == 3 then fix_string = "3D"
	elseif fix_type == 4 then fix_string = "GNSS Dead Reckoning"
	elseif fix_type == 5 then fix_string = "Time Only"
	end

	subtree:add(buffer(0,1), "Multi Ant. Heading Valid: " .. vertical_valid)
    subtree:add(buffer(0,1), "Fix Type: " .. fix_string)
    subtree:add(buffer(1,1), "Fix State: " .. buffer(1,1):uint())
    subtree:add(buffer(2,1), "Satellites: " .. buffer(2,1):uint())
    subtree:add(buffer(3,1), "PDOP: " .. buffer(3,1):uint() * 0.1)
	subtree:add(buffer(4,4), "Latitude: " .. buffer(4,4):int() / 10000000.0 .. "º")
	subtree:add(buffer(8,4), "Longitude: " .. buffer(8,4):int() / 10000000.0 .. "º")
	subtree:add(buffer(12,4), "Altitude: " .. buffer(12,4):int() / 10000.0 .. "m")
	subtree:add(buffer(16,4), "Vel North: " .. buffer(16,4):int() / 1000.0 .. " m/s")
	subtree:add(buffer(20,4), "Vel East: " .. buffer(20,4):int() / 1000.0 .. " m/s")
	subtree:add(buffer(24,4), "Vel Down: " .. buffer(24,4):int() / 1000.0 .. " m/s")

	local acc = subtree:add(buffer(28,16), "Accuracy")
	acc:add(buffer(28,4), "Horiz. Accuracy: " .. buffer(28,4):int() / 1000.0 .. "m")
	acc:add(buffer(32,4), "Vert. Accuracy: " .. buffer(32,4):int() / 1000.0 .. "m")
	acc:add(buffer(36,4), "Speed Accuracy: " .. buffer(36,4):int() / 1000.0 .. " m/s")
	acc:add(buffer(40,4), "Hdg. Accuracy: " .. buffer(40,4):int() / 100000.0 .. "º")

	subtree:add(buffer(44,4), "ITOW: " .. buffer(44,4):uint())
	subtree:add(buffer(48,2), "GPS Week: " .. buffer(48,2):uint())
	subtree:add(buffer(50,2), "Geoid Undulation: " .. buffer(50,2):int() / 100.0 .. "m")

	subtree:add(buffer(52,1), "Source: " .. get_gps_string(buffer(52,1):uint()))

	if size >= 54 then
		subtree:add(buffer(53,1), "Vertical Velocity Valid: " .. buffer(53,1):uint())
	end

	if size >= 55 then
		subtree:add(buffer(54,1), "Leap Seconds: " .. buffer(54,1):uint())
	end

	if size >= 57 then
		subtree:add(buffer(55,2), "Multi Ant. Heading: " .. buffer(55,2):int() / 32768.0 * 180)
	end

	return name
end

function print_ext_heading(subtree, buffer, id, size)
	local name = "Ext. Heading"
	subtree = make_subtree(subtree, buffer, name, id, size)

	subtree:add(buffer(0,2), "Heading: " .. buffer(0,2):int() / 32768.0 * 180.0)
	subtree:add(buffer(2,2), "Noise: " .. buffer(2,2):uint() / 32768.0 * 360.0)

	if size >= 5 then
		subtree:add(buffer(4,1), "Bitfield: " .. buffer(4,1))
	end

	return name
end

function print_ins_quality(subtree, buffer, id, size)
	local name = "INS Quality"
	subtree = make_subtree(subtree, buffer, name, id, size)

	subtree:add(buffer(0,4), "System Time: " .. buffer(0,4):uint())
	subtree:add(buffer(4,1), "GPS Source: " .. get_gps_string(buffer(4,1):uint()))

	local imu_type = bit.band(buffer(5,1):uint(), 3)
	local imu_string = "Other"

	if imu_type == 0 then imu_string = "Internal"
	elseif imu_type == 1 then imu_string = "Sensonor"
	elseif imu_type == 2 then imu_string = "DMU-11"
	end

	subtree:add(buffer(5,1), "IMU Type: " .. imu_string)

	local imu_mode = buffer(6,1):uint()

	if imu_mode == 0 then imu_string = "Init 1"
	elseif imu_mode == 1 then imu_string = "Init 2"
	elseif imu_mode == 2 then imu_string = "AHRS"
	elseif imu_mode == 3 then imu_string = "Run Hard"
	elseif imu_mode == 4 then imu_string = "Run"
	elseif imu_mode == 5 then imu_string "Run TC"
	end

	subtree:add(buffer(6,1), "INS Mode: " .. imu_string)

	local bitfield = buffer(7,1):uint()

	-- Skipping because it looks as though the scaling is broken...
	-- subtree:add(buffer(8,1), "GPS Period" .. buffer(8,1):uint() / 100.0)
	-- subtree:add(buffer(9,1), "Heading Period" .. buffer(9,1):uint() / 100.0)

	-- Skipping because I don't have a float16 to float32 conversion
	-- local chi = subtree:add(buffer(10,6), "Chi-Square Statistics")
	-- chi:add(buffer(10,2), "Position" .. buffer(10,2):uint())
	-- chi:add(buffer(12,2), "Velocity" .. buffer(12,2):uint())
	-- chi:add(buffer(14,2), "Heading" .. buffer(14,2):uint())

	local att = subtree:add(buffer(16,6), "Att. Confidence")
	att:add(buffer(16,2), "Roll: " .. math.deg(buffer(16,2):uint() / 10000.0))
	att:add(buffer(18,2), "Pitch: " .. math.deg(buffer(18,2):uint() / 10000.0))
	att:add(buffer(20,2), "Yaw: " .. math.deg(buffer(20,2):uint() / 10000.0))

	local vel = subtree:add(buffer(22,6), "Vel. Confidence")
	vel:add(buffer(22,2), "North: " .. buffer(22,2):uint() / 100.0)
	vel:add(buffer(24,2), "East: " .. buffer(24,2):uint() / 100.0)
	vel:add(buffer(26,2), "Down: " .. buffer(26,2):uint() / 100.0)

	local pos = subtree:add(buffer(28,6), "Pos. Confidence")
	pos:add(buffer(28,2), "X: " .. buffer(28,2):uint() / 100.0)
	pos:add(buffer(30,2), "Y: " .. buffer(30,2):uint() / 100.0)
	pos:add(buffer(32,2), "Z: " .. buffer(32,2):uint() / 100.0)

	local i = 34

	if bit.band(bitfield, 128) == 128 and size >= i + 6 then
		local pos = subtree:add(buffer(i,6), "Gyro Bias Confidence")
		pos:add(buffer(i+0,2), "p: " .. buffer(i+0,2):uint() / 100000.0)
		pos:add(buffer(i+2,2), "q: " .. buffer(i+2,2):uint() / 100000.0)
		pos:add(buffer(i+4,2), "r: " .. buffer(i+4,2):uint() / 100000.0)
		i = i + 6
	end

	if bit.band(bitfield, 32) == 32 and size >= i + 6 then
		local pos = subtree:add(buffer(i,6), "Accel Bias Confidence")
		pos:add(buffer(i+0,2), "X: " .. buffer(i+0,2):uint() / 30000.0)
		pos:add(buffer(i+2,2), "Y: " .. buffer(i+2,2):uint() / 30000.0)
		pos:add(buffer(i+4,2), "Z: " .. buffer(i+4,2):uint() / 30000.0)
		i = i + 6
	end

	if bit.band(bitfield, 64) == 64 and size >= i + 2 then
		subtree:add(buffer(i,2), "Gravity Bias Confidence: " .. buffer(i,2):uint() / 30000)
		i = i + 2
	end

	if bit.band(bitfield, 16) == 16 and size >= i + 4 then
		subtree:add(buffer(i+0,2), "Clock Bias Confidence: " .. buffer(i+0,2):uint() / 10000)
		subtree:add(buffer(i+2,2), "Clock Drift Confidence: " .. buffer(i+2,2):uint() / 10000)
		i = i + 4
	end

	if bit.band(bitfield, 128) == 128 and size >= i + 6 then
		local pos = subtree:add(buffer(i,6), "Gyro Bias")
		pos:add(buffer(i+0,2), "p: " .. math.deg(buffer(i+0,2):int() / 100000.0))
		pos:add(buffer(i+2,2), "q: " .. math.deg(buffer(i+2,2):int() / 100000.0))
		pos:add(buffer(i+4,2), "r: " .. math.deg(buffer(i+4,2):int() / 100000.0))
		i = i + 6
	end

	if bit.band(bitfield, 32) == 32 and size >= i + 6 then
		local pos = subtree:add(buffer(i,6), "Accel Bias")
		pos:add(buffer(i+0,2), "X: " .. buffer(i+0,2):uint() / 30000.0)
		pos:add(buffer(i+2,2), "Y: " .. buffer(i+2,2):uint() / 30000.0)
		pos:add(buffer(i+4,2), "Z: " .. buffer(i+4,2):uint() / 30000.0)
		i = i + 6
	end

	if bit.band(bitfield, 64) == 64 and size >= i + 2 then
		subtree:add(buffer(i,2), "Gravity Bias: " .. buffer(i,2):int() / 30000)
		i = i + 2
	end

	if bit.band(bitfield, 16) == 16 and size >= i + 8 then
		subtree:add(buffer(i+0,2), "Clock Bias" .. buffer(i+0,2):int() / 100)
		subtree:add(buffer(i+2,2), "Clock Drift" .. buffer(i+2,2):int() / 1000)
		subtree:add(buffer(i+4,1), "TC Sat Pos Updates: " .. buffer(i+4,1):uint())
		subtree:add(buffer(i+5,1), "TC Sat Vel Updates: " .. buffer(i+5,1):uint())
		subtree:add(buffer(i+6,1), "TC Pos Updates: " .. buffer(i+6,1):uint())
		subtree:add(buffer(i+7,1), "TC Vel Updates: " .. buffer(i+7,1):uint())
		i = i + 8
	end

	return name
end

function print_geolocate(subtree, buffer, id, size)
	local name = "Geolocate Telemetry"
	subtree = make_subtree(subtree, buffer, name, id, size)

	subtree:add(buffer(0,4), "System Time: " .. buffer(0,4):uint())
	subtree:add(buffer(4,4), "GPS Time of Week: " .. buffer(4,4):uint())
	subtree:add(buffer(8,2), "Gps Week: " .. buffer(8,2):uint())
	subtree:add(buffer(10,2), "Geoid Undulation: " .. buffer(10,2):int() / 32768.0 * 120.0)
	subtree:add(buffer(12,4), "Latitude: " .. buffer(12,4):int() / 10000000.0)
	subtree:add(buffer(16,4), "Longitude: " .. buffer(16,4):int() / 10000000.0)
	subtree:add(buffer(20,4), "Altitude: " .. buffer(20,4):int() / 10000.0)

	local gps_vel = subtree:add(buffer(24,6), "GPS Velocity")

	gps_vel:add(buffer(24,2), "North: " .. buffer(24,2):int() / 100.0)
	gps_vel:add(buffer(26,2), "East: " .. buffer(26,2):int() / 100.0)
	gps_vel:add(buffer(28,2), "Down: " .. buffer(28,2):int() / 100.0)

	local q = subtree:add(buffer(30,8), "Gimbal Quaternion")

	q:add(buffer(30,2), "a: " .. buffer(30,2):int() / 32768.0)
	q:add(buffer(32,2), "b: " .. buffer(32,2):int() / 32768.0)
	q:add(buffer(34,2), "c: " .. buffer(34,2):int() / 32768.0)
	q:add(buffer(36,2), "d: " .. buffer(36,2):int() / 32768.0)

	subtree:add(buffer(38,2), "Pan: " .. buffer(38,2):int() / 32768.0 * 180.0)
	subtree:add(buffer(40,2), "Tilt: " .. buffer(40,2):int() / 32768.0 * 180.0)

	subtree:add(buffer(42,2), "HFOV: " .. buffer(42,2):uint() / 65535.0 * 360.0)
	subtree:add(buffer(44,2), "VFOV: " .. buffer(44,2):uint() / 65535.0 * 360.0)

	if size >= 52 then
		local los = subtree:add(buffer(46,6), "ECEF Line of Sight")
		los:add(buffer(46,2), "X: " .. buffer(46,2):int())
		los:add(buffer(48,2), "Y: " .. buffer(48,2):int())
		los:add(buffer(50,2), "Z: " .. buffer(50,2):int())
	end

	if size >= 54 then
		subtree:add(buffer(52,2), "Pixel Width: " .. buffer(52,2):uint())
	end

	if size >= 56 then
		subtree:add(buffer(54,2), "Pixel Height: " .. buffer(54,2):uint())
	end

	if size >= 57 then
		subtree:add(buffer(56,1), "Mode: " .. get_mode_string(buffer(56,1):uint()))
	end

	if size >= 61 then

		local path = subtree:add(buffer(57,4), "Path Status")

		path:add(buffer(57,1), "Path Progress: " .. buffer(57,1):uint() / 255.0)

		if size >= 59 then
			path:add(buffer(58,1), "Stare Time: " .. buffer(58,1):uint() / 100.0)
		end

		if size >= 60 then
			path:add(buffer(59,1), "Path From: " .. buffer(59,1):uint())
		end

		if size >= 61 then
			path:add(buffer(60,1), "Path To: " .. buffer(60,1):uint())
		end
	end

	if size >= 76 then
		local shifts = subtree:add(buffer(61,15), "Image Shift Data")

		shifts:add(buffer(61,4), "Raw Shift X: " .. math.deg(buffer(61,4):int() / 1000000.0))
		shifts:add(buffer(65,4), "Raw Shift Y: " .. math.deg(buffer(65,4):int() / 1000000.0))
		shifts:add(buffer(69,2), "Delta Time: " .. buffer(69,2):uint() / 1000.0)
		shifts:add(buffer(71,1), "Confidence: " .. buffer(71,1):uint() / 2.55 .. "%")
		shifts:add(buffer(72,2), "Output Shift X: " .. buffer(72,2):int() / 32768.0 * 180.0)
		shifts:add(buffer(74,2), "Output Shift Y: " .. buffer(74,2):int() / 32768.0 * 180.0)
	end

	if size >= 77 then
		subtree:add(buffer(76,1), "Range Source: " .. buffer(76,1))
	end

	if size >= 78 then
		subtree:add(buffer(77,1), "Leap Seconds: " .. buffer(77,1):uint())
	end

	return name

end

function print_packet(pinfo, subtree, buffer)
	local id = buffer(2,1):uint()
	local size = buffer(3,1):uint()
	local data = buffer(4,size)
	local info = ""

	if     id == 1   then info = print_cmd(subtree, data, id, size)
	elseif id == 65 then info = print_diagnostics(subtree, data, id, size)
	elseif id == 67  then info = print_performance(subtree, data, id, size)
	elseif id == 68 then info = print_sw_diagnostics(subtree, data, id, size)
	elseif id == 209 then info = print_gps_data(subtree, data, id, size)
	elseif id == 210 then info = print_ext_heading(subtree, data, id, size)
	elseif id == 211 then info = print_ins_quality(subtree, data, id, size)
	elseif id == 212 then info = print_geolocate(subtree, data, id, size)
	else
		local name = "Unknown packet ID 0x" .. buffer(2,1)
		subtree = make_subtree(subtree, data, name, id, size)
		subtree:add(data, "Data: " .. data)
		info = name
	end

	if tostring(pinfo.cols.info) == "" then
		pinfo.cols.info = info
	else
		pinfo.cols.info = tostring(pinfo.cols.info) .. ", " .. info
	end

	return size + 6
end

-- create a function to dissect it
function orion.dissector(buffer,pinfo,tree)
	if buffer(0,2):uint() == 53261 then

	    pinfo.cols.protocol = "Orion"

	    local i = 0
	    local bytes = buffer:len()

	    pinfo.cols.info = ""

	    while i < bytes do
	    	i = i + print_packet(pinfo, tree, buffer(i, bytes - i))
	    end
	end
end

DissectorTable.get("tcp.port"):add(8747,orion)
DissectorTable.get("udp.port"):add(8748,orion)