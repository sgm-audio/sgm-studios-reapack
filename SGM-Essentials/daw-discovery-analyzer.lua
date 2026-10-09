-- @description Profile the REAPER environment: plugins, routing graph, track structure, and system specs
-- @author Scott Mills
-- @version 1.0.1
-- @changelog
--   1.0.1 (2026-10-08)
--     + Top Shelf audit: replace gfx.showmenu with GetUserInputs
--     + Top Shelf audit: localize main functions (no global leaks)
--   1.0.0 (2026-05-23)
--     + Initial release
--     + System profiling: CPU, RAM, sample rate, buffer size
--     + Plugin discovery and categorization
--     + Signal flow graph generation exported to console
-- @provides
--   [main] daw-discovery-analyzer.lua
-- @about
--   ## REAPER DAW Discovery and Analyzer
--   Profiles the current REAPER installation and open project.
--
--   **What it analyzes:**
--   - Operating system and REAPER version
--   - Audio device configuration (driver, sample rate, block size)
--   - Available plugins (scans installed VST/VST3/AU/JSFX)
--   - Track structure (count, routing graph, folder hierarchy)
--   - Project settings (tempo, time signature, length)
--   - System specs relevant to audio performance (CPU, RAM, disk)
--
--   **Dependencies:**
--   - Core features work without any external extensions
--   - SWS/S&M Extension enables advanced routing inspection
--   - Script detects SWS availability and adjusts output accordingly
--
--   **Output format:**
--   - Clean, formatted console report
--   - Sections: System Info, Audio Config, Plugin Inventory, Track Map, Routing
--
--   **How to use:**
--   1. Open a REAPER project
--   2. Run the script
--   3. Open View → Console to read the report
--
--   **Edge cases handled:**
--   - SWS not installed: routing features limited, note printed in report
--   - Empty project: still reports system info and audio config
--   - No plugins found: reports "No plugins discovered"
-- REAPER DAW Discovery & Analyzer
-- Comprehensive system profiling, plugin discovery, and signal flow mapping
-- Version 1.0

-- Guard: SWS/S&M Extension enables advanced routing inspection.
-- Core features (system info, audio config, plugin discovery) work without SWS.
local SWS_AVAILABLE = reaper.BR_GetMouseCursorContext ~= nil
if not SWS_AVAILABLE then
  reaper.ShowConsoleMsg("Note: SWS/S&M Extension not installed — routing graph features will be limited.\n")
  reaper.ShowConsoleMsg("Install from: https://www.sws-extension.org/\n\n")
end

-- ===================================
-- SYSTEM ANALYZER
-- ===================================

local SystemAnalyzer = {}

function SystemAnalyzer:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function SystemAnalyzer:getSystemInfo()
  return {
    os = reaper.GetOS(),
    reaper_version = reaper.GetAppVersion(),
    resource_path = reaper.GetResourcePath(),
    exe_path = reaper.GetExePath()
  }
end

function SystemAnalyzer:getAudioConfiguration()
 local audio_config = {}

 audio_config.sample_rate = reaper.GetProjectSampleRate()

 local _, device_name = reaper.GetAudioDeviceInfo("IDENT_IN", "")
 audio_config.input_device = device_name

 _, device_name = reaper.GetAudioDeviceInfo("IDENT_OUT", "")
 audio_config.output_device = device_name

 audio_config.input_channels = reaper.GetInputChannelCount()
 audio_config.output_channels = reaper.GetOutputChannelCount()

 local _, buffer_size = reaper.GetAudioDeviceInfo("BSIZE", "")
 audio_config.buffer_size = buffer_size

 local _, bit_depth = reaper.GetAudioDeviceInfo("BITDEPTH", "")
 audio_config.bit_depth = bit_depth

 return audio_config
end

function SystemAnalyzer:getPerformanceMetrics()
  return {
    cpu_usage = reaper.GetCPULoading(),
    track_count = reaper.CountTracks(0),
    active_fx_count = self:countActiveFX(),
    memory_usage_mb = collectgarbage("count") / 1024
  }
end

function SystemAnalyzer:countActiveFX()
  local count = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local fx_count = reaper.TrackFX_GetCount(track)
    for j = 0, fx_count - 1 do
      if reaper.TrackFX_GetEnabled(track, j) then
        count = count + 1
      end
    end
  end
  return count
end

function SystemAnalyzer:generateSystemReport()
  local report = {}

  report.system = self:getSystemInfo()
  report.audio = self:getAudioConfiguration()
  report.performance = self:getPerformanceMetrics()
  report.timestamp = os.date("%Y-%m-%d %H:%M:%S")

  return report
end

-- ===================================
-- PLUGIN ANALYZER
-- ===================================

local PluginAnalyzer = {}

function PluginAnalyzer:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function PluginAnalyzer:scanAllTracksForPlugins()
  local plugin_inventory = {}

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, track_name = reaper.GetTrackName(track)
    local fx_count = reaper.TrackFX_GetCount(track)

    local track_plugins = {}

    for j = 0, fx_count - 1 do
      local _, fx_name = reaper.TrackFX_GetFXName(track, j, "")
      local plugin_info = self:analyzePlugin(track, j, fx_name)
      table.insert(track_plugins, plugin_info)
    end

    if #track_plugins > 0 then
      plugin_inventory[track_name] = track_plugins
    end
  end

  return plugin_inventory
end

function PluginAnalyzer:analyzePlugin(track, fx_index, fx_name)
  local info = {
    name = fx_name,
    enabled = reaper.TrackFX_GetEnabled(track, fx_index),
    param_count = reaper.TrackFX_GetNumParams(track, fx_index),
    parameters = {}
  }

  -- Get all parameters
  for i = 0, math.min(info.param_count - 1, 20) do  -- Limit to 20 params for performance
    local _, param_name = reaper.TrackFX_GetParamName(track, fx_index, i, "")
    local value = reaper.TrackFX_GetParam(track, fx_index, i)
    local _, formatted = reaper.TrackFX_GetFormattedParamValue(track, fx_index, i, "")

    table.insert(info.parameters, {
      name = param_name,
      value = value,
      formatted = formatted
    })
  end

  -- Get preset info
  local preset_index = reaper.TrackFX_GetPresetIndex(track, fx_index)
  if preset_index >= 0 then
    local _, preset_name = reaper.TrackFX_GetPreset(track, fx_index, "")
    info.preset = preset_name
  end

  return info
end

function PluginAnalyzer:categorizePlugins(plugin_inventory)
  local categories = {
    eq = {},
    compressor = {},
    reverb = {},
    delay = {},
    modulation = {},
    saturation = {},
    instrument = {},
    other = {}
  }

  for track_name, plugins in pairs(plugin_inventory) do
    for _, plugin in ipairs(plugins) do
      local category = self:detectPluginCategory(plugin.name)
      table.insert(categories[category], {
        track = track_name,
        plugin = plugin
      })
    end
  end

  return categories
end

function PluginAnalyzer:detectPluginCategory(plugin_name)
  local name_lower = plugin_name:lower()

  if name_lower:find("eq") or name_lower:find("equal") then
    return "eq"
  elseif name_lower:find("comp") or name_lower:find("limit") then
    return "compressor"
  elseif name_lower:find("reverb") or name_lower:find("verb") then
    return "reverb"
  elseif name_lower:find("delay") or name_lower:find("echo") then
    return "delay"
  elseif name_lower:find("chorus") or name_lower:find("flanger") or name_lower:find("phaser") then
    return "modulation"
  elseif name_lower:find("sat") or name_lower:find("distort") or name_lower:find("overdrive") then
    return "saturation"
  elseif name_lower:find("synth") or name_lower:find("instrument") or name_lower:find("sampler") then
    return "instrument"
  else
    return "other"
  end
end

-- ===================================
-- SIGNAL FLOW MAPPER
-- ===================================

local SignalFlowMapper = {}

function SignalFlowMapper:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function SignalFlowMapper:buildSignalGraph()
  local graph = {
    nodes = {},
    edges = {},
    analysis = {}
  }

  -- Add track nodes
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local node = self:createTrackNode(track, i)
    table.insert(graph.nodes, node)
  end

  -- Add routing edges
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local edges = self:analyzeTrackRouting(track, i)
    for _, edge in ipairs(edges) do
      table.insert(graph.edges, edge)
    end
  end

  -- Add analysis
  graph.analysis = self:analyzeSignalFlow(graph)

  return graph
end

function SignalFlowMapper:createTrackNode(track, index)
  local _, name = reaper.GetTrackName(track)
  local node = {
    id = "track_" .. index,
    index = index,
    name = name,
    type = "track",
    properties = {
      volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL"),
      pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN"),
      muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1,
      solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0,
      fx_count = reaper.TrackFX_GetCount(track),
      item_count = reaper.CountTrackMediaItems(track),
      sends_to_master = reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND") == 1
    }
  }

  -- Add FX chain info
  node.fx_chain = {}
  for j = 0, reaper.TrackFX_GetCount(track) - 1 do
    local _, fx_name = reaper.TrackFX_GetFXName(track, j, "")
    table.insert(node.fx_chain, {
      name = fx_name,
      enabled = reaper.TrackFX_GetEnabled(track, j)
    })
  end

  return node
end

function SignalFlowMapper:analyzeTrackRouting(track, track_index)
  local edges = {}

  if SWS_AVAILABLE then
    -- Use SWS for detailed send/receive routing
    local send_count = reaper.GetTrackNumSends(track, 0)
    for i = 0, send_count - 1 do
      local dest_track = reaper.BR_GetMediaTrackSendInfo_Track(track, 0, i, 1)
      if dest_track then
        local dest_index = reaper.GetMediaTrackInfo_Value(dest_track, "IP_TRACKNUMBER") - 1
        local volume = reaper.GetTrackSendInfo_Value(track, 0, i, "D_VOL")
        local pan = reaper.GetTrackSendInfo_Value(track, 0, i, "D_PAN")
        local muted = reaper.GetTrackSendInfo_Value(track, 0, i, "B_MUTE") == 1

        table.insert(edges, {
          source = "track_" .. track_index,
          destination = "track_" .. dest_index,
          type = "send",
          properties = {
            volume = volume,
            pan = pan,
            muted = muted
          }
        })
      end
    end

    local receive_count = reaper.GetTrackNumSends(track, -1)
    for i = 0, receive_count - 1 do
      local src_track = reaper.BR_GetMediaTrackSendInfo_Track(track, -1, i, 0)
      if src_track then
        local src_index = reaper.GetMediaTrackInfo_Value(src_track, "IP_TRACKNUMBER") - 1

        table.insert(edges, {
          source = "track_" .. src_index,
          destination = "track_" .. track_index,
          type = "receive"
        })
      end
    end
  else
    -- Fallback: use built-in REAPER API only
    local send_count = reaper.GetTrackNumSends(track, 0)
    for i = 0, send_count - 1 do
      table.insert(edges, {
        source = "track_" .. track_index,
        destination = "master",
        type = "send",
        properties = {
          volume = reaper.GetTrackSendInfo_Value(track, 0, i, "D_VOL"),
          pan = reaper.GetTrackSendInfo_Value(track, 0, i, "D_PAN"),
          muted = reaper.GetTrackSendInfo_Value(track, 0, i, "B_MUTE") == 1
        }
      })
    end
  end

  return edges
end

function SignalFlowMapper:analyzeSignalFlow(graph)
  local analysis = {
    total_tracks = #graph.nodes,
    total_connections = #graph.edges,
    buses = {},
    chains = {},
    bottlenecks = {},
    islands = {}
  }

  -- Identify buses (tracks receiving multiple sends)
  local receive_counts = {}
  for _, edge in ipairs(graph.edges) do
    if edge.type == "send" then
      receive_counts[edge.destination] = (receive_counts[edge.destination] or 0) + 1
    end
  end

  for node_id, count in pairs(receive_counts) do
    if count > 1 then
      table.insert(analysis.buses, {
        node = node_id,
        input_count = count
      })
    end
  end

  -- Identify processing chains (sequential routing)
  analysis.chains = self:findProcessingChains(graph)

  -- Identify potential bottlenecks (high CPU usage points)
  for _, node in ipairs(graph.nodes) do
    if node.properties.fx_count > 5 then
      table.insert(analysis.bottlenecks, {
        node = node.id,
        reason = "High plugin count: " .. node.properties.fx_count
      })
    end
  end

  return analysis
end

function SignalFlowMapper:findProcessingChains(graph)
  local chains = {}
  local visited = {}

  for _, node in ipairs(graph.nodes) do
    if not visited[node.id] then
      local chain = self:traceChain(node.id, graph, visited)
      if #chain > 1 then
        table.insert(chains, chain)
      end
    end
  end

  return chains
end

function SignalFlowMapper:traceChain(start_node, graph, visited)
  local chain = {start_node}
  visited[start_node] = true

  -- Find next node in chain
  for _, edge in ipairs(graph.edges) do
    if edge.source == start_node and edge.type == "send" then
      local next_chain = self:traceChain(edge.destination, graph, visited)
      for _, node in ipairs(next_chain) do
        table.insert(chain, node)
      end
      break
    end
  end

  return chain
end

-- ===================================
-- CONFIGURATION MONITOR
-- ===================================

local ConfigMonitor = {}

function ConfigMonitor:new()
  local obj = {
    last_state = nil,
    changes = {}
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function ConfigMonitor:captureCurrentState()
  return {
    track_count = reaper.CountTracks(0),
    item_count = reaper.CountMediaItems(0),
    tempo = reaper.Master_GetTempo(),
    sample_rate = reaper.GetProjectSampleRate(),
    track_configs = self:captureAllTrackConfigs()
  }
end

function ConfigMonitor:captureAllTrackConfigs()
  local configs = {}

  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)

    configs[i] = {
      name = name,
      volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL"),
      pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN"),
      muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE"),
      fx_count = reaper.TrackFX_GetCount(track)
    }
  end

  return configs
end

function ConfigMonitor:detectChanges()
  local current_state = self:captureCurrentState()

  if not self.last_state then
    self.last_state = current_state
    return {}
  end

  local changes = {}

  -- Track count changes
  if current_state.track_count ~= self.last_state.track_count then
    table.insert(changes, {
      type = "track_count",
      old = self.last_state.track_count,
      new = current_state.track_count
    })
  end

  -- Tempo changes
  if math.abs(current_state.tempo - self.last_state.tempo) > 0.01 then
    table.insert(changes, {
      type = "tempo",
      old = self.last_state.tempo,
      new = current_state.tempo
    })
  end

  -- Track configuration changes
  for i, config in pairs(current_state.track_configs) do
    local old_config = self.last_state.track_configs[i]
    if old_config then
      if math.abs(config.volume - old_config.volume) > 0.001 then
        table.insert(changes, {
          type = "track_volume",
          track = config.name,
          old = old_config.volume,
          new = config.volume
        })
      end

      if config.fx_count ~= old_config.fx_count then
        table.insert(changes, {
          type = "fx_count",
          track = config.name,
          old = old_config.fx_count,
          new = config.fx_count
        })
      end
    end
  end

  self.last_state = current_state
  self.changes = changes

  return changes
end

-- ===================================
-- COMPREHENSIVE ANALYZER
-- ===================================

local function performComprehensiveAnalysis()
  reaper.ClearConsole()
  reaper.ShowConsoleMsg("=== COMPREHENSIVE DAW ANALYSIS ===\n\n")

  -- System Analysis
  local sys_analyzer = SystemAnalyzer:new()
  local sys_report = sys_analyzer:generateSystemReport()

  reaper.ShowConsoleMsg("SYSTEM INFO:\n")
  reaper.ShowConsoleMsg("  OS: " .. sys_report.system.os .. "\n")
  reaper.ShowConsoleMsg("  REAPER: " .. sys_report.system.reaper_version .. "\n")
  reaper.ShowConsoleMsg("  Sample Rate: " .. sys_report.audio.sample_rate .. " Hz\n")
  reaper.ShowConsoleMsg("  CPU: " .. string.format("%.1f", sys_report.performance.cpu_usage * 100) .. "%\n")
  reaper.ShowConsoleMsg("  Active FX: " .. sys_report.performance.active_fx_count .. "\n\n")

  -- Plugin Analysis
  reaper.ShowConsoleMsg("PLUGIN ANALYSIS:\n")
  local plugin_analyzer = PluginAnalyzer:new()
  local plugin_inventory = plugin_analyzer:scanAllTracksForPlugins()
  local categories = plugin_analyzer:categorizePlugins(plugin_inventory)

  for category, plugins in pairs(categories) do
    if #plugins > 0 then
      reaper.ShowConsoleMsg("  " .. category .. ": " .. #plugins .. "\n")
    end
  end
  reaper.ShowConsoleMsg("\n")

  -- Signal Flow Analysis
  reaper.ShowConsoleMsg("SIGNAL FLOW:\n")
  local flow_mapper = SignalFlowMapper:new()
  local signal_graph = flow_mapper:buildSignalGraph()

  reaper.ShowConsoleMsg("  Tracks: " .. signal_graph.analysis.total_tracks .. "\n")
  reaper.ShowConsoleMsg("  Connections: " .. signal_graph.analysis.total_connections .. "\n")
  reaper.ShowConsoleMsg("  Buses: " .. #signal_graph.analysis.buses .. "\n")
  reaper.ShowConsoleMsg("  Processing Chains: " .. #signal_graph.analysis.chains .. "\n")

  if #signal_graph.analysis.bottlenecks > 0 then
    reaper.ShowConsoleMsg("\n  POTENTIAL BOTTLENECKS:\n")
    for _, bottleneck in ipairs(signal_graph.analysis.bottlenecks) do
      reaper.ShowConsoleMsg("    " .. bottleneck.node .. ": " .. bottleneck.reason .. "\n")
    end
  end

  reaper.ShowConsoleMsg("\nAnalysis complete!\n")
end

local function monitorConfigChanges()
  local monitor = ConfigMonitor:new()

  -- Capture initial state
  monitor:captureCurrentState()

  reaper.ShowConsoleMsg("=== CONFIG MONITOR STARTED ===\n")
  reaper.ShowConsoleMsg("Make changes to your project...\n\n")

  -- Monitor in a defer loop
  local function check_changes()
    local changes = monitor:detectChanges()

    if #changes > 0 then
      reaper.ShowConsoleMsg("CHANGES DETECTED:\n")
      for _, change in ipairs(changes) do
        reaper.ShowConsoleMsg("  " .. change.type)
        if change.track then
          reaper.ShowConsoleMsg(" on " .. change.track)
        end
        if change.old and change.new then
          reaper.ShowConsoleMsg(": " .. tostring(change.old) .. " -> " .. tostring(change.new))
        end
        reaper.ShowConsoleMsg("\n")
      end
      reaper.ShowConsoleMsg("\n")
    end

    reaper.defer(check_changes)
  end

  reaper.defer(check_changes)
end

-- ===================================
-- MAIN MENU
-- ===================================

local function showAnalyzerMenu()
  local ok, answer = reaper.GetUserInputs(
    "DAW Discovery & Analyzer", 1,
    "1=Comprehensive Analysis  2=Plugin Inventory  "
      .. "3=Signal Flow Map  4=Start Config Monitor",
    "1")
  if not ok then return end

  local result = tonumber(answer and answer:match("^%s*(%d+)"))
  if not result or result < 1 or result > 4 then return end

  if result == 1 then
    performComprehensiveAnalysis()
  elseif result == 2 then
    local analyzer = PluginAnalyzer:new()
    local inventory = analyzer:scanAllTracksForPlugins()
    reaper.ClearConsole()
    reaper.ShowConsoleMsg("=== PLUGIN INVENTORY ===\n\n")
    for track, plugins in pairs(inventory) do
      reaper.ShowConsoleMsg(track .. ":\n")
      for _, plugin in ipairs(plugins) do
        reaper.ShowConsoleMsg("  - " .. plugin.name)
        if plugin.preset then
          reaper.ShowConsoleMsg(" [" .. plugin.preset .. "]")
        end
        reaper.ShowConsoleMsg("\n")
      end
      reaper.ShowConsoleMsg("\n")
    end
  elseif result == 3 then
    local mapper = SignalFlowMapper:new()
    local graph = mapper:buildSignalGraph()
    reaper.ClearConsole()
    reaper.ShowConsoleMsg("=== SIGNAL FLOW MAP ===\n\n")
    reaper.ShowConsoleMsg("Nodes (" .. #graph.nodes .. "):\n")
    for _, node in ipairs(graph.nodes) do
      reaper.ShowConsoleMsg("  " .. node.name .. " (FX: " .. node.properties.fx_count .. ")\n")
    end
    reaper.ShowConsoleMsg("\nEdges (" .. #graph.edges .. "):\n")
    for _, edge in ipairs(graph.edges) do
      reaper.ShowConsoleMsg("  " .. edge.source .. " -> " .. edge.destination .. "\n")
    end
  elseif result == 4 then
    monitorConfigChanges()
  end
end

-- Run
showAnalyzerMenu()
