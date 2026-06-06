export const meta = {
  name: 'explore-fitai-analyzer',
  description: 'Fan out Explore agents across FitAI Analyzer dimensions, then synthesize an architecture overview',
  phases: [
    { title: 'Explore', detail: '6 Explore agents: architecture, AI subsystem, sync/integrations, domain/data, UI/flows, config/build/docs' },
    { title: 'Synthesize', detail: 'integrate findings into one coherent map + reading guide' },
  ],
}

const AREA_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['area', 'summary', 'keyComponents', 'interactions', 'notableFindings', 'entryPoints'],
  properties: {
    area: { type: 'string' },
    summary: { type: 'string', description: '3-6 sentence prose summary of how this area works' },
    keyComponents: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['name', 'path', 'role'],
        properties: { name: { type: 'string' }, path: { type: 'string' }, role: { type: 'string' } },
      },
    },
    interactions: { type: 'array', items: { type: 'string' }, description: 'data flows / how this area talks to others' },
    notableFindings: { type: 'array', items: { type: 'string' }, description: 'gotchas, tech debt, TODOs, security notes, patterns' },
    entryPoints: { type: 'array', items: { type: 'string' }, description: 'best files to start reading, with one-line why' },
  },
}

const ROOT = 'C:\\\\Users\\\\c.perciun\\\\Documents\\\\Custom_WorkSpace\\\\FitAI Analyzer'

const DIMENSIONS = [
  {
    key: 'architecture',
    prompt: `Explore the ARCHITECTURE & APP BOOTSTRAP of the Flutter app at "${ROOT}". Focus on: lib/main.dart, lib/app.dart, lib/routes/app_router.dart (go_router), lib/ui/shell/main_shell_screen.dart, lib/ui/launch/launch_screen.dart, lib/providers/providers.dart and how Riverpod providers are wired, lib/theme/ and lib/ui/theme. Determine: app startup sequence (dotenv, Firebase init, error handling), the navigation graph (routes, redirects, auth gating via auth_gateway), how dependency injection works with Riverpod, the overall layer separation (ui/providers/services/models/utils) and MVVM pattern. Report the high-level architecture and how the pieces connect. Medium-thorough breadth.`,
  },
  {
    key: 'ai',
    prompt: `Explore the AI SUBSYSTEM of the Flutter app at "${ROOT}". Focus on lib/services: unified_ai_service.dart, deepseek_service.dart, gemini_service.dart, openrouter_service.dart, ai_backend_preference_service.dart, ai_prompt_service.dart, nutrition_ai_prompts.dart, nutrition_ai_json_parser.dart, nutrition_meal_plan_service.dart, gemini_api_key_service.dart, credential_storage_service.dart, user_ai_settings_sync_service.dart. Also lib/providers/pending_meal_analysis_provider.dart and lib/utils/prompt/. Determine: how the multi-backend AI abstraction works (which backends, how one is selected, the unified interface), how prompts are built and stored, how AI JSON responses are parsed/validated, how API keys are stored/secured and synced, and the meal-analysis / nutrition-plan AI flows. Note any security concerns around API keys (also check .env, TODO-SECURE-API-KEY.md). Thorough breadth.`,
  },
  {
    key: 'sync',
    prompt: `Explore FITNESS INTEGRATIONS & SYNC of the Flutter app at "${ROOT}". Focus on lib/services: garmin_service.dart, strava_service.dart, the OAuth flow files (garmin_oauth_callback, garmin_web_oauth_web/stub, strava_oauth_callback, strava_web_oauth_web/stub, strava_desktop_io/stub, strava_oauth_credentials_service), aggregation_service.dart. Also lib/sync/comm_mi_fitness_post_connect_sync.dart, lib/providers/{garmin_sync_notifier,strava_sync_status_notifier,data_sync_notifier,sync_backfill_status_provider}.dart, and docs/SYNC_ARCHITECTURE.md, docs/GARMIN_INTEGRATION.md, docs/FLUSSI_GARMIN_AI.md. Determine: how Garmin, Strava and Mi Fitness connect (OAuth, platform-specific web/desktop variants), the role of the external garmin-sync-server (Raspberry Pi), how activity/health data is fetched and aggregated, and the Firestore collections involved (daily_health, activities). Thorough breadth.`,
  },
  {
    key: 'domain',
    prompt: `Explore the DOMAIN MODELS & DATA LAYER of the Flutter app at "${ROOT}". Focus on lib/models/ (user_profile, baseline_profile_model, daily_log_model, rolling_10days_model, meal_model, fitness_data, nutrition_meal_plan_ai, longevity_*, home_widget_type, feedback_message_model, ai_current_allenamenti_model). Also lib/services: longevity_engine.dart, nutrition_calculator_service.dart, nutrition_service.dart. And docs/DATA_ARCHITECTURE.md plus the "Three-Level memory strategy" (daily_logs detail -> rolling_10days trend -> baseline_profile annual). Determine: the core domain entities and their fields, how json_serializable (.g.dart) is used, the Three-Level Firestore data strategy and how data flows between levels, what the longevity_engine computes, and how nutrition/calories are calculated. Thorough breadth.`,
  },
  {
    key: 'ui',
    prompt: `Explore the UI / FEATURES & USER FLOWS of the Flutter app at "${ROOT}". Focus on lib/ui/: home/ (home_screen + widgets like longevity_header, pillar_grid, weekly_sprint_card, home_widget_picker), dashboard/ (dashboard_screen, activity_detail/day screens, suggestions_tab), alimentazione/ (alimentazione_screen, meal_capture_flow, nutrition_meal_analysis_screen), onboarding/ (onboarding_screen, nutrition_goal_screen, main_profile fields), auth/ (auth_gateway, login_screen), profile/, impostazioni/ (settings, feedback), and lib/ui/widgets/ (charts, dialogs). Note it is an Italian-language app. Determine: the main screens and the end-to-end user journey (onboarding -> home/dashboard -> meal capture -> AI analysis), the home-widget customization system, how charts (fl_chart) are used, and how UI binds to Riverpod providers. Thorough breadth.`,
  },
  {
    key: 'config',
    prompt: `Explore CONFIG, BUILD, PLATFORMS & DOCS of the Flutter app at "${ROOT}". Focus on: pubspec.yaml/pubspec.lock (key deps), .env handling and flutter_dotenv, firebase.json + firestore.rules + lib/firebase_options.dart, the platform dirs (android, ios, web, windows, macos) at a high level, .github/ CI workflows (iOS build), the docs/ folder (README, FIREBASE_SETUP, IOS_SETUP, GITHUB_IOS_BUILD.md), .cursor/rules/ (project conventions, memory strategy), AGENTS.md, server/ folder, test/ folder, and security-relevant files (TODO-SECURE-API-KEY.md, credential_storage_service, flutter_secure_storage usage). Determine: how the app is built/configured per platform, the CI setup, Firestore security rules posture, test coverage, and the documented conventions/rules agents must follow. Thorough breadth.`,
  },
]

phase('Explore')
const findings = (await parallel(
  DIMENSIONS.map(d => () =>
    agent(d.prompt, { label: `explore:${d.key}`, phase: 'Explore', schema: AREA_SCHEMA, agentType: 'Explore' })
  )
)).filter(Boolean)

phase('Synthesize')
const synthesis = await agent(
  `You are synthesizing an exploration of the Flutter app "FitAI Analyzer" (a fitness/nutrition/longevity app: Firebase + multi-AI-backend + Garmin/Strava/Mi-Fitness sync, Italian-language, ~28K LOC Dart, Riverpod + go_router + fl_chart).\n\n` +
  `Below are structured findings from 6 parallel Explore agents (architecture, AI subsystem, sync/integrations, domain/data, UI/flows, config/build/docs). Integrate them into ONE coherent overview. Produce:\n` +
  `1. A 2-3 sentence "what this app is" elevator pitch.\n` +
  `2. A layered architecture map (UI -> providers -> services -> models, plus external systems: Firebase, AI backends, garmin-sync-server, Garmin/Strava/Mi APIs).\n` +
  `3. The key end-to-end data flows: (a) fitness sync -> Firestore -> aggregation -> UI, and (b) meal capture -> AI analysis -> nutrition data, and (c) the Three-Level memory strategy.\n` +
  `4. The most notable findings: tech debt, security concerns, gotchas, conventions.\n` +
  `5. A prioritized "where to start reading" guide (8-12 files with one-line why each).\n\n` +
  `Cross-link across areas where one area's component feeds another. Be concrete and cite file paths. Here are the findings as JSON:\n\n` +
  JSON.stringify(findings, null, 2),
  { label: 'synthesize', phase: 'Synthesize' }
)

return { findings, synthesis }
