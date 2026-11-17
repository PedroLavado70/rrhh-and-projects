import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const html=fs.readFileSync('index.html','utf8');
const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(m=>m[1]).filter(s=>s.trim());
assert.ok(scripts.length>=2,'Debe haber scripts internos.');
scripts.forEach((script,i)=>new vm.Script(script,{filename:'index.html.inline-'+i}));
assert.match(html,/window\.doLogin\s*=\s*async\s*function/);
assert.match(html,/SB\.auth\.signInWithPassword/);
assert.match(html,/SB\.auth\.signOut/);
assert.match(html,/function isIndefiniteContract/);
assert.match(html,/fin\.disabled=blocked/);
assert.match(html,/fecha_fin_contrato:fechaFin/);
assert.match(html,/historial_contratos:r\.historial_contratos\|\|\[\]/);
assert.match(html,/window\.processImport=async function\(\)\{/);
assert.doesNotMatch(html,/\.select\(['"]pwd_hash['"]\)/);
assert.doesNotMatch(html,/sigral2024!/);
assert.doesNotMatch(html,/CREATE POLICY "allow_all"/i);
assert.doesNotMatch(html,/window\.processImport\s*=\s*async function\(\)\{[\s\S]*?await SB\.from\(['"]empleados['"]\)\.insert/);

const regionStart=html.indexOf('function isIndefiniteContract(tipo){');
const regionEnd=html.indexOf('function openEmpModal(id){',regionStart);
assert.ok(regionStart>0&&regionEnd>regionStart,'Funciones de formulario no encontradas.');
const fields={
  'f-tipo':{value:'Indefinido'},
  'f-fin':{value:'2026-12-31',disabled:false,required:false,title:''}
};
const context={document:{getElementById:(id)=>fields[id]||null}};
vm.runInNewContext(html.slice(regionStart,regionEnd),context);
assert.equal(context.isIndefiniteContract('Indefinido'),true);
assert.equal(context.isIndefiniteContract(' indefinído '),true);
assert.equal(context.isIndefiniteContract('Plazo Fijo'),false);
context.syncContractEndField();
assert.equal(fields['f-fin'].value,'');
assert.equal(fields['f-fin'].disabled,true);
assert.equal(fields['f-fin'].required,false);
fields['f-tipo'].value='Plazo Fijo';
context.syncContractEndField();
assert.equal(fields['f-fin'].disabled,false);
assert.equal(fields['f-fin'].required,true);
fields['f-tipo'].value='Locación de Servicios';
context.syncContractEndField();
assert.equal(fields['f-fin'].disabled,false);
assert.equal(fields['f-fin'].required,false);

const mapperStart=html.indexOf('function sbToEmp(r){');
const mapperEnd=html.indexOf('function sbToProy(r){',mapperStart);
assert.ok(mapperStart>0&&mapperEnd>mapperStart,'Mapper de empleado no encontrado.');
const mapper={};
vm.runInNewContext(html.slice(mapperStart,mapperEnd),mapper);
const example={id:5,codigo:'EMP-5',nombres:'Prueba',apellidos:'Seguro',tipo_contrato:'Indefinido',
  fecha_fin_contrato:null,historial:[{tipo:'renovacion'}],
  historial_contratos:[{tipo:'cese',fecha_cese:'2026-10-15'}]};
const item=mapper.sbToEmp(example);
assert.equal(item.fecha_fin_contrato,'');
assert.equal(item.historial_contratos.length,1);
assert.equal(item.historial.length,1);
console.log('OK: RH-001 (bloqueo/desbloqueo), fechas nulas e historiales contractual y laboral.');

console.log('OK: sintaxis de scripts internos + invariantes estáticas RH-001 y Auth.');
