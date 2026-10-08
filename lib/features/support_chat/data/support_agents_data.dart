import '../domain/models/support_agent.dart';

/// Agentes por assunto (Kids, Financeiro, Mídia, Pastoral). Desligado: só o Moisés
/// ("default") aparece, sem transferência, Central de Agentes nem edição de agentes.
/// Os agentes continuam configurados; para voltar, troque para true.
const bool kMultiAgentsEnabled = false;

const Map<String, SupportAgent> kSupportAgents = {
  "default": SupportAgent(
    key: "default",
    name: "Atendimento",
    role: "Suporte geral",
    iconName: "support_agent",
    defaultThemeColorHex: "#3F8CFF",
    defaultShowFloatingButton: true,
  ),
  "kids": SupportAgent(
    key: "kids",
    name: "Ministério Infantil",
    role: "Cuidado e ensino bíblico das crianças",
    iconName: "child_care",
    defaultWelcomeMessage:
        "Oi! Somos o Ministério Infantil 😊 Como podemos ajudar você com culto infantil, escala, materiais ou dúvidas sobre as crianças?",
    defaultThemeColorHex: "#FF9E00",
  ),
  "media": SupportAgent(
    key: "media",
    name: "Mídia",
    role: "Conteúdos & transmissões",
    iconName: "movie",
    defaultThemeColorHex: "#7C3AED",
  ),
  "financeiro": SupportAgent(
    key: "financeiro",
    name: "Financeiro",
    role: "Contribuições & Ofertas",
    iconName: "payments",
    defaultThemeColorHex: "#00C853",
  ),
  "pastoral": SupportAgent(
    key: "pastoral",
    name: "Pastoral",
    role: "Aconselhamento",
    iconName: "volunteer_activism",
    defaultThemeColorHex: "#D4AF37",
  ),
};
