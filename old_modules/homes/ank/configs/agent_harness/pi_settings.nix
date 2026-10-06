{
  defaultThinkingLevel = "medium";
  theme = "dark";
  compaction = {
    enabled = true;
    reserveTokens = 16384;
    keepRecentTokens = 20000;
  };
  retry = {
    enabled = true;
    maxRetries = 3;
  };
  warnings = {
    anthropicExtraUsage = true;
  };
  packages = [
    "pi-subagents"
    "pi-mcp-adapter"
  ];
}
