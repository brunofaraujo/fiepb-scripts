# Compliance de Ativação Windows

Scripts para auditoria e remediação do licenciamento do Windows em estações corporativas.

---

## Invoke-ActivationCompliance.ps1

Ferramenta interativa que detecta ferramentas ilegais de ativação do Windows, remove todos os seus vestígios e/ou reseta a ativação para um novo processo de licenciamento.

### Requisitos

- Windows 10 ou Windows 11
- PowerShell 5.1+
- Executar **como Administrador**

### Como executar

```powershell
# Abra o PowerShell como Administrador e execute:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Invoke-ActivationCompliance.ps1
```

### Menu de opções

| Opção | Ação |
|---|---|
| `[1]` Escanear | Verifica a presença de ativadores ilegais. **Não faz alterações.** |
| `[2]` Remover + Resetar | Remove artefatos ilegais encontrados e reseta a ativação do Windows. |
| `[3]` Resetar ativação | Reseta a ativação atual (legítima ou não) para preparo de novo processo. |
| `[4]` Sair | Encerra o script. |

### O que é detectado

**Ferramentas de ativação ilegal:**
- KMSpico / KMSELDI
- KMSAuto Net / KMSAuto Lite
- AAct / AAct Network
- AutoKMS
- KMS_VL_ALL

**Artefatos verificados:**
- Arquivos e pastas em caminhos conhecidos (System32, ProgramData, perfis de usuário)
- Tarefas agendadas criadas por ativadores
- Serviços do Windows instalados por ativadores
- Chaves de registro suspeitas
- Servidor KMS apontando para `localhost` / `127.0.0.1`

### Reset de ativação

O reset executa os seguintes comandos `slmgr`:

```
slmgr /upk   → Remove a chave de produto instalada
slmgr /ckms  → Limpa o servidor KMS configurado
slmgr /rearm → Reseta o contador de licenciamento (período de graça)
```

Após o reset, o Windows entra em período de graça e está pronto para receber uma nova ativação legítima (chave de volume corporativa, KMS do domínio, ou MAK).

### Log de auditoria

Todas as ações são registradas em:

```
C:\Windows\Logs\ActivationCompliance_AAAAMMDD_HHMMSS.log
```

---

> **Autor:** Bruno Araujo — Setor de TI  
> Consulte [`docs/compliance-ativacao.md`](../../docs/compliance-ativacao.md) para guia completo.
