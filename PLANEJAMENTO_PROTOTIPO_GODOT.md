# Quimagic — Planejamento Técnico e Arquitetura do Protótipo (Godot 4)

Este documento registra as decisões de arquitetura técnica, tecnologias avaliadas e o plano de desenvolvimento definidos para o protótipo do jogo **Quimagic** utilizando a **Godot Engine 4** e exportação para **Navegador (Web/HTML5)**.

---

## 1. Contexto do Projeto & Alinhamento com o GDD
O jogo **Quimagic** une narrativa fantasiosa com aprendizado gamificado de química:
* **Protagonista:** Hidro, transportada para ajudar o mago Mendeleev a reconstruir o conhecimento alquímico/químico contra o vilão Ur-Novem Duo.
* **Core Loop do Protótipo:**
  1. **Exploração e Coleta (Top-Down):** Movimentação estilo *Pokémon* / *Goof Troop* / *Zelda aLttP*, explorando biomas, coletando elementos gasosos/minerais (ex.: Hidrogênio $H$ e Oxigênio $O$).
  2. **Bancada Alquímica / Síntese (1ª Pessoa):** Combinação das substâncias na proporção correta ($2H + O \rightarrow H_2O$).
  3. **Resolução no Mapa:** Aplicação da solução para dissolver barreiras químicas (ex.: barreira de sal $NaCl$ dissolvida por água $H_2O$ como solvente universal).

---

## 2. Engine e Ambiente de Desenvolvimento
* **Engine:** Godot 4.x (Renderizador *GL Compatibility* com fallback otimizado para navegadores e mobile).
* **Linguagem Principal:** GDScript (rápida iteração, tipagem estática opcional e serialização nativa para cenas `.tscn` e recursos `.tres`).
* **Suporte do Agent na IDE:**
  - Codificação completa de controladores de personagem, física, gerenciamento de estados (*State Machines*).
  - Configurações de entradas (*Input Map*), física e projeto em `project.godot`.
  - Construção de cenas (`.tscn`), UI e sistemas de integração via nós nativos (`TileMapLayer`, `Area2D`, `HTTPRequest`, etc.).

---

## 3. Pipeline Visual & Criação de Sprites (Nano Banana / IA Nativa)
* **Acesso e Autenticação:**
  - **Sem necessidade de API Key externa:** A IDE dispõe de ferramenta nativa integrada de geração de imagens baseada nos modelos Google (família Nano Banana / Imagen).
  - O Agent gera os assets sob demanda a partir de descrições textuais e os salva diretamente na estrutura de pastas do projeto (ex.: `res://assets/sprites/...`).
* **Aplicações no Quimagic:**
  - *Sprite sheets* de personagens em perspectiva top-down (andando em 4 ou 8 direções).
  - *Tilesets* e texturas para os biomas elementais.
  - Ilustrações de itens, frascos, compostos químicos e elementos de interface (UI).
  - Recorte e fatiamento via nós `Sprite2D` e `AnimatedSprite2D` com parâmetros de atlas (`hframes` / `vframes`).

---

## 4. Arquitetura do Mapa Top-Down e Geração Procedural
* **Sistema de Cenário:**
  - Uso de nós `TileMapLayer` do Godot 4 com suporte a **Terrains (Autotiling)** para transição orgânica entre tipos de solo (grama, caminhos, água, rochas).
* **Geração Procedural Híbrida:**
  - **`FastNoiseLite`:** Algoritmos de ruído nativos do Godot (Simplex/Perlin/Cellular) para criar distribuição suave de biomas, manchas de recursos e lagos.
  - **Uso de Imagens como Inspiração / Esqueleto:**
    - Leitura programática de mapas/sketches de referência via `Image.load_from_file()` ou prefabs desenhados.
    - Mapeamento de cores em biomas (ex.: pixel azul = água, verde = grama/bosque, bege = sal/deserto), com ruído procedural aplicando variações locais e obstáculos.
  - **Mecânica Estilo Pokémon:**
    - Movimentação baseada em grade (Grid Movement em passos de 16x16 ou 32x32 pixels) ou analógica suave com colisão.
    - Zonas de coleta e gatilhos de evento via nós `Area2D` posicionados proceduralmente.

---

## 5. Persistência de Dados & Backend (Supabase + PostgreSQL)
Para garantir execução estável no **Navegador (Godot Web)** com suporte a salvamento na nuvem e dados relacionais de química:

* **Viabilidade Técnica no Navegador:**
  - O navegador não permite conexões diretas via portas TCP brutas (ex.: porta 5432 do PostgreSQL).
  - O **Supabase** resolve isso oferecendo comunicação **100% via HTTPS REST (PostgREST)** e **WebSockets (Realtime)**, que funcionam nativamente no export Web do Godot através do nó `HTTPRequest`.
* **Vantagens para o Quimagic:**
  - **PostgreSQL & JSONB:** Excelente para modelar tabelas periódicas, inventário de elementos, fórmulas conhecidas e progresso do jogador.
  - **Segurança (RLS - Row Level Security):** Regras de autorização aplicadas no banco protegem dados de save mesmo com a chave pública (`anon_key`) no cliente web.
  - **Autenticação:** Login anônimo/convidado (Guest), e-mail ou autenticação social sem necessidade de infraestrutura própria.
* **Estratégia de Salvamento Híbrida Recomendada:**
  1. **Cache Local Imediato:** Salvar no diretório `user://save.json` do Godot (no navegador, é automaticamente persistido no **IndexedDB** local, sem custo e funcional offline).
  2. **Sincronização em Nuvem:** Quando houver conexão ou o usuário estiver autenticado, sincronizar via requisição REST (`POST`/`PATCH`) com o Supabase.

---

## 6. Próximos Passos Práticos

1. **Configuração das Camadas de Entrada e Projeto:**
   - Mapear controles direcionais (`ui_up`, `ui_down`, `ui_left`, `ui_right`, `interact`) em [`project.godot`](project.godot).
2. **Estrutura de Pastas do Projeto:**
   - Criar pastas organizadas: `res://scenes/`, `res://scripts/`, `res://assets/sprites/`, `res://data/`.
3. **Protótipo Fase 1 (Top-Down):**
   - Criação da cena do jogador (`CharacterBody2D`) com movimentação top-down e câmera suave (`Camera2D`).
   - Implementação de um `TileMapLayer` com script de geração procedural básica e nós de coleta de $H$ e $O$.
4. **Protótipo Fase 2 (Bancada Química):**
   - Interface de drag & drop para combinar elementos e checar a reação de síntese ($H_2O$).
