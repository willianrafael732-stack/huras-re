const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const site=require('../site-pages.js');
for(const base of ['https://example.test/index.html','https://example.test/h-main/index.html']){
 const prefix=new URL('.',base).pathname;
 for(const page of site.pages){assert(fs.existsSync(path.join(__dirname,'..',page.path)),page.path);assert.equal(site.resolve(page.path,base).pathname,prefix+page.path)}
 assert.equal(site.resolve('funcoes/bestiario?embed=1#fichas',base).pathname,prefix+'funcoes/bestiario.html');
 assert.equal(site.resolve('mesa/',base).pathname,prefix+'mesa/index.html');
 const sheet=site.resolve('funcoes/clan.html?open=abc%20123#ficha',base);assert.equal(sheet.searchParams.get('open'),'abc 123');assert.equal(sheet.hash,'#ficha');
 for(const bad of ['https://outside.test/a.html','javascript:alert(1)','funcoes/nao-existe.html','../segredo.html'])assert.throws(()=>site.resolve(bad,base));
}
console.log('Rotas: páginas existentes, publicação na raiz/subpasta, parâmetros e destinos inválidos: OK.');
