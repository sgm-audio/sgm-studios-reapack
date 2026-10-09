-- @description Plugin chain configuration library for the Rule of 30 heavy metal session builder
-- @author Scott Mills
-- @version 1.0.1
-- @changelog
--   1.0.1 (2026-10-08)
--     + Top Shelf audit: localize helper functions (no global leaks)
--   1.0.0 (2026-05-23)
--     + Initial release
--     + Plugin chains for Waves, iZotope, FabFilter, Neural DSP, Soundtoys
--     + Per-instrument preset tables: kick, snare, guitars, bass, vocals
-- @noindex
-- @about
--   ## Rule of 30 Plugin Presets
--   Configuration library required by rule-of-30-session-builder.lua.
--   Not intended to be run standalone. Listed as [nomain] in the session
--   builder's @provides manifest.
-- RULE OF 30 - PLUGIN PRESET CONFIGURATIONS
-- Professional Plugin Chains for Heavy Industrial Production
-- Maps specific Waves, iZotope, FabFilter, Neural DSP, Soundtoys plugins
-- Version 1.0

-- ===================================
-- PLUGIN DATABASE
-- ===================================

local PLUGIN_CHAINS = {

  -- ===================================
  -- I. DRUM BUS CHAINS
  -- ===================================

  drums = {
    kick_in = {
      name = "Kick In (Click/Attack)",
      chain = {
        {plugin = "VST3: Waves SSL E-Channel (Waves)", params = "Gate hard, boost 4kHz"},
        {plugin = "VST3: Smack Attack (Waves)", params = "Max transient attack"},
      },
      notes = "High-pass to isolate the click, gate to remove bleed"
    },

    kick_out = {
      name = "Kick Out (Body)",
      chain = {
        {plugin = "VST3: Neutron 4 (iZotope)", params = "Sculptor module for low-end fundamental"},
        {plugin = "VST3: dbx 160 (Waves)", params = "Fast, hard compression"},
      },
      notes = "Lock in the 60-80Hz fundamental, compress for weight"
    },

    kick_sub = {
      name = "Kick Sub (Sine Trigger)",
      chain = {
        {plugin = "VST3: Submarine (Waves)", params = "45Hz sub-octave synthesis"},
      },
      notes = "Pure 45Hz sine wave to rattle ribcages"
    },

    snare_top = {
      name = "Snare Top",
      chain = {
        {plugin = "VST3: CLA-76 Bluey (Waves)", params = "All buttons in mode"},
        {plugin = "VST3: Trash 2 (iZotope)", params = "Convolve module with metallic IR"},
      },
      notes = "Aggressive parallel compression + metallic saturation"
    },

    snare_bottom = {
      name = "Snare Bottom",
      chain = {
        {plugin = "VST3: H-EQ (Waves)", params = "Aggressive HPF to isolate wires"},
      },
      notes = "Just the rattle of the wires"
    },

    glitch_snare = {
      name = "Glitch Snare (Duplicate)",
      chain = {
        {plugin = "VST3: Stutter Edit 2 (iZotope)", params = "MIDI-triggered rapid-fire fills"},
      },
      notes = "Route MIDI to this track for stutter effects"
    },

    toms = {
      name = "Toms (Rack/Floor)",
      chain = {
        {plugin = "VST3: API 2500 (Waves)", params = "Link channels for cohesive image"},
      },
      notes = "Glue the toms together in stereo"
    },

    overheads = {
      name = "Overheads",
      chain = {
        {plugin = "VST3: Abbey Road TG Mastering Chain (Waves)", params = "Spread + Limiter"},
      },
      notes = "Crush the room tone, widen the image"
    },

    room_mono = {
      name = "Room Mono (Crushed)",
      chain = {
        {plugin = "VST3: Decapitator (Soundtoys)", params = "Punish button ON"},
        {plugin = "VST3: MDMX (Waves)", params = "Fuzz setting", optional = true},
      },
      notes = "Parallel compress to death for energy"
    }
  },

  -- ===================================
  -- II. BASS ENGINE (3-Band Split)
  -- ===================================

  bass = {
    bass_di = {
      name = "Bass DI (The Lows)",
      chain = {
        {plugin = "VST3: MaxxBass (Waves)", params = "Extend low-end perception"},
        {plugin = "VST3: Pro-Q 3 (FabFilter)", params = "Low pass at 200Hz"},
        {plugin = "VST3: C6 Multiband (Waves)", params = "Sidechain low band to Kick"},
      },
      notes = "Pure low-end, ducking when kick hits"
    },

    bass_amp = {
      name = "Bass Amp (The Mids)",
      chain = {
        {plugin = "VST3: Darkglass Ultra (Neural DSP)", params = "Heavy bass amp"},
        {plugin = "VST3: GTR3 (Waves)", params = "Alternative if no Neural DSP", optional = true},
        {plugin = "VST3: Neutron 4 (iZotope)", params = "Exciter module 400-800Hz"},
      },
      notes = "High-pass at 200Hz, add grit and presence"
    },

    bass_fuzz = {
      name = "Bass Fuzz (The Highs)",
      chain = {
        {plugin = "VST3: Trash 2 (iZotope)", params = "Multiband distortion 2kHz+ sizzle"},
        {plugin = "VST3: Doubler (Waves)", params = "Subtle width"},
      },
      notes = "High-pass at 200Hz, add distorted highs for definition"
    },

    bass_synth = {
      name = "Bass Synth Layer",
      chain = {
        {plugin = "VST3: Element (Waves)", params = "Saw wave on root notes"},
        {plugin = "VST3: Serum (Xfer)", params = "Alternative synth", optional = true},
        {plugin = "VST3: MetaFlanger (Waves)", params = "Slow rate for movement"},
      },
      notes = "Simple saw wave following the bass line"
    }
  },

  -- ===================================
  -- III. GUITAR WALL OF SOUND
  -- ===================================

  guitars = {
    rhythm_main = {
      name = "Rhythm Guitars L/R (100%)",
      chain = {
        {plugin = "VST3: Archetype Gojira (Neural DSP)", params = "Heavy amp setting"},
        {plugin = "VST3: SSL G-Channel (Waves)", params = "Cut 400Hz mud"},
      },
      notes = "Main rhythm tone - hard panned L/R"
    },

    rhythm_secondary = {
      name = "Rhythm Guitars L2/R2 (80%)",
      chain = {
        {plugin = "VST3: Archetype Gojira (Neural DSP)", params = "Different cab IR"},
        {plugin = "VST3: CLA-3A (Waves)", params = "Optical compression"},
      },
      notes = "Secondary rhythm layer with different tone"
    },

    texture_leads = {
      name = "Octave Leads",
      chain = {
        {plugin = "VST3: H-Delay (Waves)", params = "Ping-pong 1/8 dot"},
        {plugin = "VST3: Valhalla Shimmer", params = "Pitch-shifted reverb"},
      },
      notes = "High melody lines with delay/reverb"
    },

    texture_talking = {
      name = "Texture Guitars (Talking)",
      chain = {
        {plugin = "VST3: VocalSynth 2 (iZotope)", params = "Biovox module for talking guitar"},
      },
      notes = "Run guitar through vocal synth for growling texture"
    },

    scrape = {
      name = "The Scrape",
      chain = {
        {plugin = "VST3: Berzerk Distortion (Waves)", params = "Go crazy"},
      },
      notes = "Pick scrapes and feedback noises only"
    }
  },

  -- ===================================
  -- IV. INDUSTRIAL GLITCH & ATMOSPHERE
  -- ===================================

  glitch = {
    data_stream = {
      name = "Data Stream Bus",
      chain = {
        {plugin = "VST3: Iris 2 (iZotope)", params = "Spectral synth with modem/HDD clicks"},
      },
      notes = "Load samples of dial-up modems and hard drive sounds"
    },

    impacts = {
      name = "Impacts/Boom",
      chain = {
        {plugin = "VST3: Bass Slapper (Waves)", params = "As percussion"},
        {plugin = "VST3: R-Bass (Waves)", params = "Sub-bass enhancement"},
      },
      notes = "Hit on the 'One' of every chorus"
    },

    risers = {
      name = "White Noise Risers",
      chain = {
        {plugin = "VST3: Doppler (Waves)", params = "Automate pitch and pan"},
      },
      notes = "Transition effects between sections"
    },

    glitch_master = {
      name = "Glitch Bus Master",
      chain = {
        {plugin = "VST3: Stutter Edit 2 (iZotope)", params = "Play live via MIDI"},
      },
      notes = "Route all FX to this bus, play glitches during breakdown"
    }
  },

  -- ===================================
  -- V. VOCAL CHAINS (Dual-Layer)
  -- ===================================

  vocals = {
    lead_core = {
      name = "Lead Vocal (Core)",
      chain = {
        {plugin = "VST3: Nectar 4 (iZotope)", params = "Pitch correction + de-essing"},
        {plugin = "VST3: CLA Vocals (Waves)", params = "Rock setting"},
        {plugin = "VST3: Saturn 2 (FabFilter)", params = "Warm tube saturation"},
      },
      notes = "Intelligible main vocal"
    },

    lead_tuned = {
      name = "Lead Vocal (Hard-Tuned)",
      chain = {
        {plugin = "VST3: Waves Tune Real-Time (Waves)", params = "Speed 0.1ms, instant snap to Bb Minor"},
      },
      notes = "Use this for robotic vocal sound"
    },

    demon_layer = {
      name = "Demon Layer",
      chain = {
        {plugin = "VST3: Ovox (Waves)", params = "Pitch -12 semitones, lock to scale"},
      },
      notes = "Mix under lead at -8dB to -10dB"
    },

    telephonic = {
      name = "Telephonic Layer",
      chain = {
        {plugin = "VST3: Q10 (Waves)", params = "Band-pass 500Hz-3kHz"},
        {plugin = "VST3: Trash 2 (iZotope)", params = "Bitcrush + sample rate reduction"},
      },
      notes = "Corrupted digital sound"
    },

    whispers = {
      name = "Whisper Tracks L/R",
      chain = {
        {plugin = "VST3: Brauer Motion (Waves)", params = "Auto-pan around head"},
        {plugin = "VST3: Renaissance DeEsser (Waves)", params = "Heavy de-essing"},
      },
      notes = "ASMR-style whispers hard panned"
    },

    scream_throw = {
      name = "Scream Throw",
      chain = {
        {plugin = "VST3: EchoBoy (Soundtoys)", params = "Automation: unmute send on last word"},
        {plugin = "VST3: H-Delay (Waves)", params = "Alternative delay", optional = true},
      },
      notes = "Delay send automated for echo throws"
    }
  },

  -- ===================================
  -- VI. MASTER BUS
  -- ===================================

  master = {
    bus_comp = {
      name = "SSL Bus Compressor",
      chain = {
        {plugin = "VST3: SSL G-Master Buss Compressor (Waves)", params = "Slow attack, auto release, 4:1, 2-3dB GR"},
      },
      notes = "Glue the mix together"
    },

    tape = {
      name = "Tape Saturation",
      chain = {
        {plugin = "VST3: J37 Tape (Waves)", params = "Adds glue and warmth"},
      },
      notes = "Softens digital harshness"
    },

    mastering = {
      name = "Mastering Chain",
      chain = {
        {plugin = "VST3: Ozone 11 Advanced (iZotope)", params = "Stabilizer + Impact modules"},
        {plugin = "VST3: Pro-L 2 (FabFilter)", params = "Modern mode limiter"},
      },
      notes = "Final polish and loudness"
    }
  }
}

-- ===================================
-- SEND FX CONFIGURATIONS
-- ===================================

local SEND_FX_CHAINS = {
  reverb_hall = {
    name = "Hall Reverb",
    chain = {
      {plugin = "VST3: H-Reverb (Waves)", params = "Hall preset, pre-delay 30ms"},
      {plugin = "ReaEQ", params = "HPF 200Hz, LPF 8kHz"},
    },
    notes = "Main reverb send for vocals/leads"
  },

  reverb_plate = {
    name = "Plate Reverb",
    chain = {
      {plugin = "VST3: Abbey Road Plates (Waves)", params = "Plate setting, decay 2.0s"},
    },
    notes = "Snare reverb"
  },

  delay_quarter = {
    name = "1/4 Note Delay",
    chain = {
      {plugin = "VST3: H-Delay (Waves)", params = "1/4 note, 35% feedback"},
    },
    notes = "Rhythmic delay for vocals"
  },

  delay_dotted = {
    name = "1/8 Dotted Delay",
    chain = {
      {plugin = "VST3: EchoBoy (Soundtoys)", params = "1/8 dot, ping-pong"},
      {plugin = "VST3: H-Delay (Waves)", params = "Alternative", optional = true},
    },
    notes = "Dotted eighth delay for leads"
  },

  parallel_crush = {
    name = "Parallel Drum Crush",
    chain = {
      {plugin = "VST3: CLA-76 (Waves)", params = "All buttons in, ratio 20:1"},
      {plugin = "ReaEQ", params = "Boost 100Hz +3dB, boost 10kHz +4dB"},
    },
    notes = "Parallel compression for drums (blend 30%)"
  }
}

-- ===================================
-- PLUGIN SEARCH PATTERNS
-- ===================================

local PLUGIN_SEARCH = {
  -- Waves plugins (try multiple formats)
  waves = {
    "VST3: %s (Waves)",
    "VST: Waves %s",
    "VSTi: Waves %s",
  },

  -- iZotope plugins
  izotope = {
    "VST3: %s (iZotope)",
    "VST: iZotope %s",
  },

  -- FabFilter plugins
  fabfilter = {
    "VST3: %s (FabFilter)",
    "VST: FabFilter %s",
  },

  -- Neural DSP plugins
  neuraldsp = {
    "VST3: %s (Neural DSP)",
    "VST: Neural DSP %s",
  },

  -- Soundtoys plugins
  soundtoys = {
    "VST3: %s (Soundtoys)",
    "VST: Soundtoys %s",
  }
}

-- ===================================
-- HELPER FUNCTIONS
-- ===================================

local function findPlugin(track, plugin_name)
  -- Try to find plugin by name (case-insensitive)
  local fx_count = reaper.TrackFX_GetCount(track)

  for i = 0, fx_count - 1 do
    local _, fx_name = reaper.TrackFX_GetFXName(track, i, "")
    if fx_name:lower():find(plugin_name:lower()) then
      return i
    end
  end

  return nil
end

local function getChainForTrack(track_name)
  -- Match track name to plugin chain configuration

  -- Drums
  if track_name:find("Kick In") then
    return PLUGIN_CHAINS.drums.kick_in
  elseif track_name:find("Kick Out") then
    return PLUGIN_CHAINS.drums.kick_out
  elseif track_name:find("Kick Sub") then
    return PLUGIN_CHAINS.drums.kick_sub
  elseif track_name:find("Snare Top") then
    return PLUGIN_CHAINS.drums.snare_top
  elseif track_name:find("Snare Bottom") then
    return PLUGIN_CHAINS.drums.snare_bottom
  elseif track_name:find("Glitch Snare") then
    return PLUGIN_CHAINS.drums.glitch_snare
  elseif track_name:find("Tom") then
    return PLUGIN_CHAINS.drums.toms
  elseif track_name:find("OH") or track_name:find("Overhead") then
    return PLUGIN_CHAINS.drums.overheads
  elseif track_name:find("Room Mono") then
    return PLUGIN_CHAINS.drums.room_mono

  -- Bass
  elseif track_name:find("Bass DI") then
    return PLUGIN_CHAINS.bass.bass_di
  elseif track_name:find("Bass Amp") then
    return PLUGIN_CHAINS.bass.bass_amp
  elseif track_name:find("Bass Fuzz") then
    return PLUGIN_CHAINS.bass.bass_fuzz
  elseif track_name:find("Bass Synth") then
    return PLUGIN_CHAINS.bass.bass_synth

  -- Guitars
  elseif track_name:find("Rhythm L1") or track_name:find("Rhythm R1") then
    return PLUGIN_CHAINS.guitars.rhythm_main
  elseif track_name:find("Rhythm L2") or track_name:find("Rhythm R2") then
    return PLUGIN_CHAINS.guitars.rhythm_secondary
  elseif track_name:find("Octave Lead") then
    return PLUGIN_CHAINS.guitars.texture_leads
  elseif track_name:find("Scrape") then
    return PLUGIN_CHAINS.guitars.scrape

  -- Vocals
  elseif track_name:find("Lead Vocal") then
    return PLUGIN_CHAINS.vocals.lead_core
  elseif track_name:find("Demon Layer") then
    return PLUGIN_CHAINS.vocals.demon_layer
  elseif track_name:find("Telephonic") then
    return PLUGIN_CHAINS.vocals.telephonic
  elseif track_name:find("Whisper") then
    return PLUGIN_CHAINS.vocals.whispers
  end

  return nil
end

-- ===================================
-- EXPORT
-- ===================================

return {
  chains = PLUGIN_CHAINS,
  send_fx = SEND_FX_CHAINS,
  search = PLUGIN_SEARCH,
  getChainForTrack = getChainForTrack,
  findPlugin = findPlugin
}
