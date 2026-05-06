# Guia: Sanitizador de Ativação do Windows

**Script:** `Invoke-ActivationCompliance.ps1`  
**Autor:** Bruno Araujo — Setor de TI  
**Versão:** 1.0.0

---

## Objetivo

Garantir que as estações de trabalho Windows da empresa utilizem somente ativações legítimas, em conformidade com as normas anti-pirataria e políticas corporativas de licenciamento de software.

---

## Contexto

Ferramentas de ativação ilegal (também chamadas de *cracks*, *keygens* ou *ativadores KMS piratas*) modificam o sistema operacional para simular ativação, instalando serviços, tarefas agendadas, arquivos em pastas do sistema e chaves de registro que podem:

- Comprometer a segurança e estabilidade do sistema
- Impedir que atualizações de segurança sejam instaladas corretamente
- Gerar inconsistências em auditorias de licenciamento
- Expor a empresa a riscos legais e de conformidade

---

## Ativadores detectados

| Ferramenta | Tipo de ativação |
|---|---|
| **KMSpico** | Emula servidor KMS local |
| **KMSELDI** | Variante do KMSpico |
| **KMSAuto Net** | Emula servidor KMS local |
| **KMSAuto Lite** | Versão simplificada do KMSAuto |
| **AAct / AAct Network** | KMS + HWID bypass |
| **AutoKMS** | Tarefa agendada de re-ativação KMS |
| **KMS_VL_ALL** | Script unificado de ativação KMS |

---

## Indicadores de ativação ilegal

Além dos artefatos físicos (arquivos, serviços, tarefas), o script também identifica:

### Servidor KMS local suspeito

Uma instalação legítima de KMS em domínio aponta para um servidor corporativo real (ex.: `kms.empresa.com.br` ou um IP interno dedicado). Quando o KMS aponta para `127.0.0.1` ou `localhost`, indica que um emulador KMS foi instalado localmente.

Para verificar manualmente:

```powershell
cscript C:\Windows\System32\slmgr.vbs /dli
```

Se a linha `Nome do Computador KMS` mostrar `127.0.0.1` ou `localhost`, a ativação é ilegítima.

---

## Procedimento de remediação (Opção 2)

Quando ativadores ilegais são detectados, a sequência de remediação é:

1. **Parar e remover serviços ilegais** — evita que arquivos estejam em uso
2. **Remover tarefas agendadas** — impede re-ativação automática
3. **Remover arquivos e pastas** — limpa os binários do ativador
4. **Remover chaves de registro** — elimina configurações residuais
5. **Reset de ativação** — desativa o Windows e o prepara para nova ativação legítima

Todos os passos solicitam confirmação do operador antes de executar.

---

## Reset de ativação (Opção 3)

Útil quando se deseja mover uma estação para um novo modelo de licenciamento (ex.: migração de MAK para KMS corporativo, ou troca de chave de volume).

**Comandos executados:**

```
slmgr /upk   → Desinstala a chave de produto do sistema
slmgr /ckms  → Remove a configuração de servidor KMS
slmgr /rearm → Reinicia o contador de ativação (período de graça de 30 dias)
```

> **Nota:** O comando `/rearm` é limitado. O Windows 10/11 permite até 3 rearms antes de exigir reinstalação para resetar o contador. Em ambientes corporativos gerenciados por KMS, o rearm geralmente não é necessário — basta reinstalar a chave e apontar para o servidor KMS correto.

---

## Após a remediação

Com o Windows resetado, ative normalmente conforme o método corporativo:

**Ativação por KMS corporativo:**
```powershell
# Instalar chave de volume (GVLK da Microsoft para sua edição)
cscript slmgr.vbs /ipk <CHAVE-GVLK>

# Apontar para o servidor KMS da empresa
cscript slmgr.vbs /skms kms.empresa.com.br

# Ativar
cscript slmgr.vbs /ato
```

**Ativação por MAK (Multiple Activation Key):**
```powershell
cscript slmgr.vbs /ipk <CHAVE-MAK>
cscript slmgr.vbs /ato
```

---

## Log de auditoria

O script grava todas as ações em:

```
C:\Windows\Logs\ActivationCompliance_AAAAMMDD_HHMMSS.log
```

Recomenda-se copiar esses logs para o sistema de gestão de chamados ou pasta de rede do setor de TI após cada intervenção.

---

## Perguntas frequentes

**O script pode ser executado remotamente via PSRemoting?**  
Sim, desde que a sessão remota seja estabelecida com privilégios de Administrador. Alguns comandos `slmgr` podem requerer interação local.

**O script remove o Office pirata?**  
Na versão atual, o foco é o Windows. Detecção e remoção de ativadores do Office serão adicionadas em versão futura.

**O script reinicia a máquina?**  
Não automaticamente. Após o reset de ativação, é recomendado reiniciar manualmente.

**Posso usar como script de logon de domínio?**  
Não é recomendado para logon — o script é interativo e requer confirmações. Para uso em GPO, considere criar uma versão silenciosa futura com parâmetros `-Automatico` e `-SemConfirmacao`.

---

## Histórico de versões

| Versão | Data | Descrição |
|---|---|---|
| 1.0.0 | 2026-05-06 | Versão inicial: detecção e remoção de ativadores Windows |
