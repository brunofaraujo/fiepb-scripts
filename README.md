# fiepb-scripts

[![Build & Release](https://github.com/brunofaraujo/fiepb-scripts/actions/workflows/build-release.yml/badge.svg)](https://github.com/brunofaraujo/fiepb-scripts/actions/workflows/build-release.yml)

Repositório de scripts PowerShell para automação e gestão do ambiente Windows corporativo.

Desenvolvido e mantido por **Bruno Araujo** — Setor de TI.

---

## Download rápido

| Ferramenta | Download |
|---|---|
| Sanitizador de Ativação do Windows | [⬇ ActivationCompliance.zip](https://github.com/brunofaraujo/fiepb-scripts/releases/latest/download/ActivationCompliance.zip) · [⬇ .exe direto](https://github.com/brunofaraujo/fiepb-scripts/releases/latest/download/ActivationCompliance.exe) |

> Baixe o `.zip`, extraia e execute o `.exe` — sem instalação, sem dependências.

---

## Sobre o projeto

Este repositório centraliza scripts utilizados no dia a dia do suporte e administração de TI, abrangendo compliance, auditoria, manutenção e provisionamento de estações de trabalho Windows 10/11 ingressadas no domínio corporativo.

Cada script é documentado, versionado e testado para uso seguro em ambientes com Active Directory.

---

## Estrutura do repositório

```
fiepb-scripts/
├── docs/                          # Documentação detalhada por área
│   └── compliance-ativacao.md
└── scripts/
    └── compliance/                # Scripts de conformidade e licenciamento
        ├── README.md
        └── Invoke-ActivationCompliance.ps1
```

---

## Scripts disponíveis

### Sanitizador de Ativação do Windows

| Script | Descrição |
|---|---|
| [`Invoke-ActivationCompliance.ps1`](scripts/compliance/Invoke-ActivationCompliance.ps1) | Detecta e remove ativadores ilegais do Windows; reseta a ativação para novo processo |

---

## Requisitos gerais

- **Sistema operacional:** Windows 10 / Windows 11
- **PowerShell:** versão 5.1 ou superior
- **Privilégios:** Administrador local (obrigatório para todos os scripts)
- **Domínio:** Scripts compatíveis com ambientes Active Directory

---

## Como usar

**Opção 1 — Executável (recomendado para usuários finais)**

Baixe o `.exe` na seção [Download rápido](#download-rápido) acima e execute diretamente.

**Opção 2 — Script PowerShell (para administradores e desenvolvimento)**

1. Clone ou baixe o repositório
2. Abra o PowerShell **como Administrador**
3. Navegue até a pasta do script desejado
4. Execute:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\NomeDoScript.ps1
```

> Cada script possui documentação própria em sua pasta e em `docs/`.

---

## Logs

Os scripts geram logs em `C:\Windows\Logs\` com nome e timestamp da execução para auditoria posterior.

---

## Autor

**Bruno Araujo**  
Setor de TI — FIEPB  
GitHub: [@brunofaraujo](https://github.com/brunofaraujo)

---

## Licença

Distribuído sob a [licença MIT](LICENSE).  
Uso autorizado exclusivamente em ambientes corporativos com finalidade de compliance e administração.
