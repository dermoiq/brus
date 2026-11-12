--!strict
-- Per-zone lighting moods, tweened on the client by ZoneController. "Quarry" must match the base values
-- baked into default.project.json (and docs/02-visual-style.md).
--
-- LightingStyle / PrioritizeLightingQuality are not script-settable, so they live only in the place file.

export type Preset = {
	Lighting: { [string]: any },
	Atmosphere: { [string]: any },
	ColorCorrection: { [string]: any },
	Bloom: { [string]: any },
}

local rgb = Color3.fromRGB

local Presets: { [string]: Preset } = {
	Quarry = {
		Lighting = {
			ClockTime = 16.4,
			Brightness = 3,
			Ambient = rgb(62, 58, 82),
			OutdoorAmbient = rgb(134, 122, 158),
			ColorShift_Top = rgb(255, 222, 184),
			ColorShift_Bottom = rgb(58, 44, 92),
			ExposureCompensation = 0.1,
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0.2,
			Color = rgb(198, 178, 255),
			Decay = rgb(104, 84, 150),
			Glare = 0.4,
			Haze = 1.5,
		},
		ColorCorrection = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.2, TintColor = rgb(255, 246, 236) },
		Bloom = { Intensity = 0.8, Size = 30, Threshold = 1.3 },
	},

	Grotto = {
		Lighting = {
			ClockTime = 20.5,
			Brightness = 2,
			Ambient = rgb(40, 74, 82),
			OutdoorAmbient = rgb(60, 110, 120),
			ColorShift_Top = rgb(120, 255, 220),
			ColorShift_Bottom = rgb(20, 50, 60),
			ExposureCompensation = 0.2,
		},
		Atmosphere = {
			Density = 0.42,
			Offset = 0.1,
			Color = rgb(90, 200, 190),
			Decay = rgb(20, 70, 80),
			Glare = 0,
			Haze = 2.2,
		},
		ColorCorrection = { Brightness = 0.03, Contrast = 0.18, Saturation = 0.3, TintColor = rgb(215, 255, 245) },
		Bloom = { Intensity = 1.1, Size = 36, Threshold = 1.1 },
	},

	Frost = {
		Lighting = {
			ClockTime = 10.5,
			Brightness = 3.2,
			Ambient = rgb(90, 110, 140),
			OutdoorAmbient = rgb(160, 190, 225),
			ColorShift_Top = rgb(225, 240, 255),
			ColorShift_Bottom = rgb(70, 90, 140),
			ExposureCompensation = 0.25,
		},
		Atmosphere = {
			Density = 0.36,
			Offset = 0.25,
			Color = rgb(190, 220, 255),
			Decay = rgb(120, 150, 200),
			Glare = 0.6,
			Haze = 1.2,
		},
		ColorCorrection = { Brightness = 0.03, Contrast = 0.1, Saturation = 0.05, TintColor = rgb(232, 244, 255) },
		Bloom = { Intensity = 0.9, Size = 28, Threshold = 1.25 },
	},

	Magma = {
		Lighting = {
			ClockTime = 18.2,
			Brightness = 2.4,
			Ambient = rgb(90, 40, 30),
			OutdoorAmbient = rgb(150, 80, 60),
			ColorShift_Top = rgb(255, 170, 110),
			ColorShift_Bottom = rgb(110, 30, 20),
			ExposureCompensation = 0.05,
		},
		Atmosphere = {
			Density = 0.48,
			Offset = 0.05,
			Color = rgb(255, 140, 90),
			Decay = rgb(120, 30, 20),
			Glare = 0.2,
			Haze = 2.6,
		},
		ColorCorrection = { Brightness = 0, Contrast = 0.2, Saturation = 0.25, TintColor = rgb(255, 228, 210) },
		Bloom = { Intensity = 1.2, Size = 40, Threshold = 1 },
	},

	Celestial = {
		Lighting = {
			ClockTime = 0.2,
			Brightness = 1.6,
			Ambient = rgb(70, 55, 120),
			OutdoorAmbient = rgb(110, 90, 180),
			ColorShift_Top = rgb(200, 170, 255),
			ColorShift_Bottom = rgb(40, 20, 90),
			ExposureCompensation = 0.35,
		},
		Atmosphere = {
			Density = 0.28,
			Offset = 0.4,
			Color = rgb(160, 120, 255),
			Decay = rgb(60, 30, 140),
			Glare = 0.8,
			Haze = 1,
		},
		ColorCorrection = { Brightness = 0.04, Contrast = 0.15, Saturation = 0.35, TintColor = rgb(235, 225, 255) },
		Bloom = { Intensity = 1.3, Size = 44, Threshold = 0.95 },
	},
}

return {
	Presets = Presets,
	Default = "Quarry",
}
