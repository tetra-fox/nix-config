---@diagnostic disable: undefined-global
-- rnnoise-dynamic.lua
--
-- Creates an RNNoise-filtered virtual Audio/Source for every real
-- alsa_input.* source as it appears, and tears it down when the
-- real source goes away.

Log                      = Log.open_topic("s-rnnoise-dynamic")

local rnnoise_so         =
"@rnnoise_plugin@/lib/ladspa/librnnoise_ladspa.so"

local raw_args           = ...
local args               = (raw_args and raw_args:parse(1)) or {}

local vad_threshold      = args["vad.threshold"] or 60.0
local vad_grace_ms       = args["vad.grace-ms"] or 200
local vad_retro_grace_ms = args["vad.retro-grace-ms"] or 0

-- node.id -> LocalModule. Dropping the reference unloads the module.
local filter_modules     = {}

local function sanitize(s)
  return (s:gsub("[^%w]", "_"))
end

local function build_filter_args(node)
  local props         = node.properties
  local node_name     = props["node.name"]
  local friendly      = props["node.description"] or node_name
  local channels      = tonumber(props["audio.channels"]) or 1

  local label         = (channels > 1)
      and "noise_suppressor_stereo"
      or "noise_suppressor_mono"

  local safe          = sanitize(node_name)
  local capture_name  = "capture.rnnoise_" .. safe
  local playback_name = "rnnoise_" .. safe
  local description   = friendly .. " (RNNoise)"

  return Json.Object {
    ["node.description"] = description,
    ["media.name"]       = description,
    ["filter.graph"]     = Json.Object {
      nodes = Json.Array {
        Json.Object {
          type    = "ladspa",
          name    = "rnnoise",
          plugin  = rnnoise_so,
          label   = label,
          control = Json.Object {
            ["VAD Threshold (%)"]          = vad_threshold,
            ["VAD Grace Period (ms)"]      = vad_grace_ms,
            ["Retroactive VAD Grace (ms)"] = vad_retro_grace_ms,
          },
        },
      },
    },
    ["capture.props"]    = Json.Object {
      ["node.name"]     = capture_name,
      ["node.passive"]  = true,
      ["target.object"] = node_name,
      ["audio.rate"]    = 48000, -- must be 48000 per RNNoise documentation
    },
    ["playback.props"]   = Json.Object {
      ["node.name"]        = playback_name,
      ["node.description"] = description,
      ["media.class"]      = "Audio/Source",
      ["audio.rate"]       = 48000,
    },
  }
end

SimpleEventHook {
  name = "rnnoise-dynamic/create",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "node-added" },
      Constraint { "media.class", "=", "Audio/Source", type = "pw-global" },
      Constraint { "node.name", "#", "alsa_input.*", type = "pw-global" },
    },
  },
  execute = function(event)
    local node = event:get_subject()
    local id   = node.id

    if filter_modules[id] then
      return
    end

    local node_name = node.properties["node.name"]
    Log:info(node, "creating RNNoise filter for " .. node_name)

    local m = LocalModule(
      "libpipewire-module-filter-chain",
      build_filter_args(node):get_data(),
      {})

    if m == nil then
      Log:warning(node, "filter-chain LocalModule returned nil for " .. node_name)
      return
    end

    filter_modules[id] = m
  end,
}:register()

SimpleEventHook {
  name = "rnnoise-dynamic/destroy",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "node-removed" },
      Constraint { "media.class", "=", "Audio/Source", type = "pw-global" },
      Constraint { "node.name", "#", "alsa_input.*", type = "pw-global" },
    },
  },
  execute = function(event)
    local node = event:get_subject()
    local id   = node.id

    if filter_modules[id] then
      Log:info(node, "removing RNNoise filter for node id " .. id)
      filter_modules[id] = nil
    end
  end,
}:register()
