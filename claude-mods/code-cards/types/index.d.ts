export type CopiedIds = string[]

declare module 'claude-code' {
  interface PluginState {
    'code-cards': { copied: Shaped<CopiedIds> }
  }
}
