# ⚗️ Quimagic

> 🧪 *Onde a magia da alquimia encontra o poder da química!*

**Quimagic** é um protótipo de jogo educativo e de aventura desenvolvido na **Godot Engine 4**, que une narrativa fantasiosa com aprendizado prático de química. Acompanhe **Hidro** em uma jornada para ajudar o velho mago **Mendeleev** a reconstruir o conhecimento da Tabela Periódica e enfrentar as barreiras impostas pelo tirano radioativo **Ur-Novem Duo**.

---

## 📜 A História

Durante uma demonstração com Ácido Nítrico em sala de aula, a curiosidade de **Hidro** a leva para perto demais da capela de exaustão. Uma falha na reação libera uma névoa rosa intensa que rompe o vidro e a transporta para outro mundo.

Ao despertar no laboratório de **Mendeleev, o Arquiteto da Tabela**, Hidro descobre que o vilão **Ur-Novem Duo** confiscou as pesquisas do mago e isolou os povos elementais com barreiras químicas para impedir o avanço da ciência. Para replicar a reação de retorno e voltar para casa, Hidro precisará explorar o continente, coletar elementos puros e dominar a **Bancada Alquímica**!

---

## 🎮 Jogabilidade & Core Loop

O protótipo combina exploração *top-down* com experimentos em primeira pessoa no caldeirão:

1. **🧭 Exploração e Coleta (Top-Down)**
   - Explore o mapa procedural controlando Hidro em 8 direções.
   - Colete elementos químicos puros espalhados pelos biomas (como **Hidrogênio** perto de fontes termais e **Oxigênio** em áreas de ventania).

2. **⚗️ Bancada de Mendeleev / Síntese (1ª Pessoa)**
   - Arraste e solte (*Drag & Drop*) reagentes dos reservatórios diretamente para o caldeirão.
   - Controle a alavanca térmica entre **Gelo** (resfriamento) e **Fogo** (Baixo, Médio, Alto) para atingir a energia de ativação correta.
   - Descubra compostos estáveis, ganhe cartas de descoberta e observe mudanças de estado físico da matéria.
   - ⚠️ **Cuidado com reações perigosas!** Misturar **Sódio (`Na`)** com **Água (`H₂O`)** em fogo médio ou alto causa uma explosão no laboratório.

3. **💧 Resolução no Mapa**
   - Utilize os compostos sintetizados — como a **Água (`H₂O`)**, o solvente universal — para dissolver as **Barreiras de Sal (`NaCl`)** e liberar novas áreas do mapa.

---

## ⚛️ Elementos e Reações no Protótipo

### 🧪 Elementos Coletáveis
| Símbolo | Elemento | Características |
| :---: | :--- | :--- |
| `H` | **Hidrogênio** | Gás mais leve do universo, coletado perto de fontes termais. |
| `O` | **Oxigênio** | Gás essencial para combustão e respiração, comum em áreas de ventania. |
| `Na` | **Sódio** | Metal alcalino macio e altamente reativo. |
| `Cl` | **Cloro** | Ametal gasoso esverdeado da família dos halogênios. |
| `C` | **Carbono** | Base da vida e do carvão; reage com oxigênio sob calor. |

### 🔮 Compostos & Experiências
* **💧 Água (`H₂O`)** — `2 H + O → H₂O` *(Fogo Baixo+)*
  * Solvente universal capaz de dissolver barreiras de sal.
  * Também permite experimentar mudanças de estado físico na bancada: **Solidificação** com gelo (`< 0 °C`) e **Vaporização** com fogo médio/alto (`> 100 °C`).
* **🧂 Cloreto de Sódio (`NaCl`)** — `Na + Cl → NaCl` *(Temperatura Ambiente)*
  * Ligação iônica entre sódio e cloro formando o sal comum.
* **🫧 Dióxido de Carbono (`CO₂`)** — `C + 2 O → CO₂` *(Fogo Médio+)*
  * Gás produzido pela combustão do carbono.
* **💥 Reação Exotérmica (`Na + H₂O`)**
  * Em fogo médio/alto, explode o laboratório. Com gelo no forno, o resfriamento absorve o calor e evita a explosão!

---

## 🕹️ Controles

| Ação | Tecla / Entrada |
| :--- | :--- |
| Movimentar Hidro | `W` `A` `S` `D` ou **Setas direcionais** |
| Interagir | `E` |
| Abrir / Fechar Bancada Alquímica | `B` |
| Manipular reagentes e alavanca térmica | **Mouse** (*Click / Drag & Drop*) |

---

## 🛠️ Tecnologias e Estrutura

* **Engine:** Godot 4.7 (`GL Compatibility`)
* **Linguagem:** GDScript
* **Física:** Jolt Physics

```text
quimagic-prototype/
├── assets/          # Sprites, tilesets, fontes e elementos visuais
├── docs/            # Documentação de design do jogo (GDD)
├── scenes/          # Cenas (.tscn) de UI, intro, mundo, player, props e bancada
│   ├── bench/       # Bancada alquímica em primeira pessoa
│   ├── intro/       # Cena narrativa inicial na sala de aula
│   ├── player/      # Personagem jogável (Hidro)
│   ├── props/       # Cristais de sal, árvores, cavernas e objetos do mapa
│   ├── ui/          # Menu principal e telas de encerramento
│   └── world/       # Mundo, gerador procedural de mapa e coletáveis
├── scripts/         # Lógica em GDScript (química, estado do jogo, mundo e UI)
└── project.godot    # Configurações principais do projeto
```

---

## ▶️ Como Executar

1. Baixe ou clone este repositório.
2. Abra a **Godot Engine 4.7** (ou compatível com Godot 4).
3. Clique em **Importar** e selecione o arquivo `project.godot` na raiz do projeto.
4. Pressione **F5** (ou clique no botão **Play**) para iniciar a partir da cena principal (`scenes/ui/main_menu.tscn`).

---

## 📄 Direitos Autorais e Uso

Copyright © 2026 **Danillo Evangelista Cabral**. Todos os direitos reservados.

Este projeto é disponibilizado publicamente apenas para fins de **portfólio e avaliação técnica/acadêmica**. Não é permitida a cópia, modificação, distribuição ou uso comercial deste código sem autorização prévia por escrito. Para mais detalhes, consulte o arquivo [LICENSE](./LICENSE).