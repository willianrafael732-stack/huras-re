# Hurras Fantasy

Site estático de RPG. Os arquivos publicados estão em `h-main/`.

## Publicação

No Netlify, use a raiz do repositório como diretório base e `h-main` como diretório de publicação; não há etapa de build. A configuração está em `netlify.toml`.

## Páginas principais

- `h-main/index.html`: portal e navegação.
- `h-main/funcoes/catalogo.html`: páginas organizadas por categoria.
- `h-main/funcoes/bestiario.html`: criaturas e chefes.
- `h-main/funcoes/deuses.html`: panteões e fichas divinas.
- `h-main/funcoes/mistura-elementos.html`: combinador de elementos.
- `h-main/cofre.html`: fichas salvas.
- `h-main/mesa/index.html`: mesa de RPG.

`h-main/site-pages.js` contém as rotas válidas usadas pelo portal e catálogo. Ao adicionar páginas, atualize esse índice.

## Verificação

Execute `node h-main/tests/d10.cjs`, `node h-main/tests/customization.cjs`, `node h-main/tests/element-mixtures.cjs` e `node h-main/tests/site-routes.cjs`.
