--[[ 
ESA_Transfer.lua

SIMION user program 
to run a series of simulations through ESA_Transfer.iob
varying float voltage, eV lens, or injection voltage

Vfloat = Float voltage [V]
Vlens  = Lens voltage [V]
Vinj   = Injection voltage [V]

Total simulations to run = nfloat * nlens * ninj

UPDATES:
15.08.16 - Parametric Excitation Added - Not experimented with enough!
05.04.17 - Magnetic Field Added
05.07.17 - Added Vinj to control injection pipe voltage separately from float voltage
19.10.17 - Added Vesa to control ESA float voltage
		 - Re-ordered adjustable variables to reflect order of components from ESA upwards
23.10.17 - Added option to loop through injection lens voltages
24.10.17 - Added progress bar GUI
25.10.17 - Added separate .xls log file containing adjustable variable values
		 - Improved comments
		 - Benchmarked script, moved initial static potential set up to init_p_values from fast_adjust
		 - Added commented out code to benchmark script
18.01.18 - Added Bx_mT, Bz_mT, to control magnetic field in all directions		 
		 
		 
NEXT:
- Expand GUI to include adjustable variables in more readable interface?
--]]

simion.workbench_program()
simion.early_access(8.2)

------- Declaration of variables -------

-- Adjustable Variables
-- Adjustable voltages, loop parameters and timing options
adjustable Vesa   = -100   -- ESA float voltage [V]
adjustable Vfloat = -100   -- Float voltage [V]
adjustable Vlens  =  -35   -- Initial lens voltage [V]
adjustable Vinj   = -100   -- Injection pipe voltage [V]
adjustable Vext   =    0   -- External electrode voltage [V]
adjustable Vint   = -330   -- Final internal electrode voltage [V]

adjustable nfloat =    1   -- No. of iterations for float voltage
adjustable nlens  =    1   -- No. of iterations for lens voltage
adjustable ninj   =    1   -- No. of iterations for injection voltage

adjustable vi_f   =    0   -- Float voltage increment [V]
adjustable vi_l   =    0   -- Lens voltage increment [V]
adjustable vi_i   =    0   -- Injection voltage increment [V]

adjustable max_t  =  1E5   -- Max. time [µs]
adjustable t_on   =   42   -- Vint switch on time [µs]


-- Parametric Excitation Adjustable Variables
adjustable ParaEx       = 0       -- Parametric Excitation [ON = 1 // OFF = 0]
adjustable ac_v         = 3       -- AC voltage [V]
adjustable target_mass  = 100     -- Target excitation mass [u]
adjustable excite_start = 50e-6   -- Excitation start time [s]
adjustable t_excite_s   = 100e-3  -- Excitation duration [s]

-- Magnetic Field Adjustable Variables 05.04.17
-- See Ion Energy, Voltages & QLT Geometry.xlsx to calculate required B-field for given deflection
adjustable Bx_mT =   0  -- Magnetic field strength coaxial with transfer optics [mT]
adjustable By_mT =   0  -- Magnetic field strength perpendicular to transfer optics [mT]
adjustable Bz_mT =   0  -- Magnetic field strength perpendicular to trasnfer optics [mT]
adjustable x1    = 380  -- x-centre of magnetic field [mm]
adjustable x_w   =  50  -- x-width of magnetic field region [mm]
adjustable y1    = 1.9  -- y-centre of magnetic field [mm]
adjustable y_w   =  20  -- y-width of magnetic field region [mm]
adjustable z1    =   0  -- z-centre of magnetic field [mm]
adjustable z_w   =  20  -- z-width of magnetic field region [mm]
adjustable mag   =   0  -- Magnetic field OFF/ON [0/1] 


-- Local Variables
local instances = simion.wb.instances -- var containing PA instance names
local vf -- float voltage
local v2 -- voltage on cylinder 2 of einzel lens
local vi -- injection voltage
local R1  = 6e-3  -- int. electrode radius [m]
local R2  = 15e-3 -- ext. electrode radius [m]
local Rm  = 22e-3 -- characteristic radius [m]
local q   = 1.6021766208E-19  -- elementary charge [C]
local amu = 1.660539040E-27   -- 1u in [kg] 


------- GUI setup -------

-- Progress bar GUI
local total  = nfloat * nlens * ninj  -- Total simulations to be run
local icount = 0                      -- Loop count for iterations
local prog   = '1/'..tostring(total); -- Initial 1/total for progress bar

local w = simion.experimental.dialog { -- Progress bar dialog
  {nil, 0.0, type='progress', id='p'},
  {'-', id = 'sum'},
  modal=false
}


------- Log file (.xls) parameters -------

-- Set up .xls log file parameters
-- Set filename and path, comment out row of unsued directory
-- Ext. HD working directory: I:\\JH PhD\\2. SIMION\\1. Simulation Workbenches\\6. ESA\\Output\\
-- Laptop working directory:  C:\\Users\\James\\Desktop\\SIMION 18.01.18\\
local folder = "I:\\JH PhD\\2. SIMION\\1. Simulation Workbenches\\6. ESA\\Output\\" -- folder for .xls log save
--local folder = "C:\\Users\\James\\Desktop\\SIMION 18.01.18\\" -- folder for .xls log save
local fname  = "text2.xls"    -- filename for .xls log save
local fpath  = folder..fname  -- path for .xls log save
local k_runs = 0;             -- Count no. of simulations performed

-- Function to write arrays to file
function write_file_numbers(filename, array)
  local f = assert(io.open(filename, 'a'))
  for _,v in ipairs(array) do
    f:write(v,'\t')
  end
  f:close()
end


-- -- Code to benchmark script execution time
-- local t0 = os.time()
-- -- code to be evaluated
-- -- place dt inside terminate segment to benchmark entire script
-- -- place dt inside fly'm segment loop k3 to benchmark voltage loops
-- local dt = os.time() - t0
-- print(dt)


------- SIMION LUA segments -------

-- Initialize segment, called after each ion is initialised for the next fly'm
--- Writes .xls log file at beginning of first simulation
--- Increments simulation count for each run
function segment.initialize_run()

if k_runs == 0 then -- Only write to .xls on first simulation

	-- Set up arrays to write to log in segment, to access updated adjustable variables
	local adjh    = {'Adjustable Variables\n'}
	local adjvars = {'Vesa',Vesa,'\n','Vfloat',Vfloat,'\n','Vlens',Vlens,'\n',
					'Vinj',Vinj,'\n','Vext',Vext,'\n','Vint',Vint,'\n',
					'nfloat',nfloat,'\n','ninj',ninj,'\n','vi_f',vi_f,'\n',
					'vi_l',vi_l,'\n','vi_i',vi_i,'\n','max_t',max_t,'\n',
					't_on',t_on,'\n','ParaEx',ParaEx,'\n','ac_v',ac_v,'\n',
					'target_mass',target_mass,'\n','excite_start',excite_start,'\n',
					't_excite_s',t_excite_s,'\n','By_mT',By_mT,'\n','x1',x1,'\n',
					'x_w',x_w,'\n','y1',y1,'\n','y_w',y_w,'\n','z1',z1,'\n',
					'z_w',z_w,'\n','mag',mag}
		
	local total_fly_count = {'Total ions flown',sim_ions_count,'\n'} -- total ions flown, for writing to .xls log file
		
	-- Write created arrays to .xls log file
	write_file_numbers(fpath, {''})
	write_file_numbers(fpath, total_fly_count)
	write_file_numbers(fpath, adjh)
	write_file_numbers(fpath, adjvars)
	
end

k_runs = k_runs + 1 -- increment no. of simulations performed

end



-- Fly'm segment 
--- Loops through float, lens and injection voltages
--- Runs new fly'm for each combination
--- Prints voltages to log (.csv)
--- Updates progress bar
function segment.flym()
	--- sim_trajectory_image_control = 1 -- don't preserve trajectories
	local total  = nfloat * nlens * ninj  -- Total simulations to be run
	w:update(function(data,event) data.sum = tostring(icount)..'/'..tostring(total) end) -- update progress text
	 
	 -- loop to iterate through float voltage from Vfloat to (Vfloat + vi_f*(n-1))
	 for k1 = 1, nfloat do
		vf = Vfloat + (vi_f * (k1-1))
		-- loop to iterate through lens voltages from v0 to (v0 + vi_l*(n-1))
		for k2 = 1, nlens do
		   v2 = Vlens + (vi_l * (k2-1))
		   	-- loop to iterate through lens voltages from v0 to (v0 + vi_l*(n-1))
			for k3 = 1, ninj do
				vi = Vinj + (vi_i * (k3-1))
				icount = icount + 1
				prog = tostring(icount)..'/'..tostring(total)
				run()
				print("Float Voltage = ,",     vf,",V") -- print float voltage
				print("Lens Voltage = ,",      v2,",V") -- print lens voltage
				print("Injection Voltage = ,", vi,",V") -- print injection voltage, end of csv
				w:update(function(data,event) data.sum = tostring(icount)..'/'..tostring(total) end) -- update progress text
				w:update(function(t,e) t.p = t.p + 1/total end) -- update progress bar
			end
		end
	end
end

-- Init_p_values segment, called prior to ions flying
--- Initialise static potential of ESA using set values for adjustable variable Vesa
--- Set Float voltage
--- Set Lens voltage
--- Set Injection voltage
function segment.init_p_values()
	
	-- set ESA static voltage
	if instances[ion_instance].filename == 'bigesa2_edit.pa0' then
		adj_elect01 = Vesa
		adj_elect02 = Vesa
		adj_elect03 = Vesa
	end
	
	-- set float voltage, lens voltage and injection voltage
	if instances[ion_instance].filename == 'ESA_Transfer.pa0' then
		-- set focal lens voltage
		adj_elect02 = v2

		if adj_elect01 ~= vf then
			-- set float voltage only if different to existing voltage
			adj_elect01 = vf
			adj_elect03 = vf
			adj_elect04 = vf
			adj_elect05 = vf
			adj_elect06 = vf
			adj_elect07 = vf
			adj_elect08 = vf
			adj_elect09 = vf
			adj_elect10 = vf
			
			-- if adjustable injection electrode is specified, set relevant electrodes accordingly
			if Vinj ~= Vfloat then
				adj_elect08 = Vinj
				adj_elect09 = Vinj
				adj_elect10 = Vinj
			end
		end
	end
	
end


-- Fast_adjust segment, called multiple times per time step
--- Sets the following voltages:
--- ESA Float Voltage
--- Focal Lens Voltage (elect02)
--- Float Voltage (elect01 - elect10, excluding elect02)
--- QLT Electrodes
function segment.fast_adjust()

	if instances[ion_instance].filename == 'QLT_2mmFillet_0.2mmGap_6mmZinj.pa0' then

		-- Voltage waveform to be applied to int. electrode, {t, v} [µs, V]
		local wave = {
		{  0,  0}, -- initial voltage
		{ t_on,  0},
		{ t_on + 1.2,  0.8*Vint},
		{ t_on + 3, 1*Vint},
		{math.huge,  Vint}  -- infinity, final voltage
		}

		local t = ion_time_of_flight + ion_time_step * 0.5
		 
		-- Locate current line segment [n-1, n] of the waveform
		local n
		for m = 1, #wave do
			n = m; if wave[m][1] > t then break end
		end

		-- Obtain points (t1,v1) and (t2,v2) of that line segment
		local t1, t2, v1, v2 = wave[n-1][1], wave[n][1], wave[n-1][2], wave[n][2]

		-- Linearly interpolate potential over the line segment
		local v = v1 + (t - t1) * ((v2-v1)/(t2-t1))

		-- Store voltage
		-- Change electrode number to desired electrode
		 adj_elect01 = v
		 
		 -- Calculated variables
		local k = 2 * abs(Vint-Vext) / ((Rm^2 * ln(R2/R1)) - 0.5 * (R2^2 - R1^2)) -- Field curv. 
		local m = target_mass * amu            -- target mass [kg]
		local omega_rad = 2 * (k * q / m )^0.5 -- Parametric excitation freq. [rad/s]
		 
		-- Set external electrodes to desired voltage
		 adj_elect02 = Vext
		 adj_elect03 = Vext
		 
		-- Parametric Excitation
		if ParaEx == 1 then
			if (ion_time_of_flight >= excite_start * 1E6 and ion_time_of_flight <= (excite_start + t_excite_s) * 1E6) then
			adj_elect01 = ac_v * sin(omega_rad * 1E-6 * ion_time_of_flight) + Vint
			end
		end 
		 
	end
end


-- Magnetic Field Section
--- If magnetic field is on (mag = 1);
--- Applies magnetic field to ion when within defined region
--- x1, y1, z1 = centre of B-field region
--- xw, yw, zw = half-width of B-field region, extending out from centre
function segment.mfield_adjust()
-- Change magnetic field at ion's location if within defined field region
	if mag == 1 then
		if ion_px_mm > x1 - 0.5*x_w and ion_px_mm < x1 + 0.5*x_w and
			ion_py_mm > y1 - 0.5*y_w and ion_py_mm < y1 + 0.5*y_w and
			ion_pz_mm > z1 - 0.5*z_w and ion_pz_mm < y1 + 0.5*z_w then
				-- Note: SIMION uses gauss (G) as its unit for magnetic fields
				--		 1 G = 1E-4 T = 0.1 mT => 1 mT = 10 G
				ion_bfieldx_gu = Bx_mT*10
				ion_bfieldy_gu = By_mT*10
				ion_bfieldz_gu = Bz_mT*10
				print('Mag On')
		else 
			ion_bfieldx_gu = 0
			ion_bfieldy_gu = 0
			ion_bfieldz_gu = 0
		end
	end
end


-- Other_actions segment, called after each ion's time step
--- Sets ion colour to green after parametric excitation finishes
--- Limits ion flight time
function segment.other_actions()

-- Set ion colour to green after parametric excitation period
 if (ion_time_of_flight > excite_start * 1E6 and ParaEx == 1) then
    ion_color = 2
 end

-- Limit flight time
  if ion_time_of_flight > max_t then
    ion_splat = 1 
 end

end

-- Terminate segment, called after all ions have stopped flying
--- Retains potentials changed in init_p_values segment; Vesa only
function segment.terminate()
	sim_retain_changed_potentials = 1 -- retain init_p_values changes
end

------- End of ESA_Transfer.lua -------
