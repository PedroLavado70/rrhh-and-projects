import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const code=fs.readFileSync('scripts/backup-local.js','utf8');
const writes=[];
function makeDir(name='root'){
 const dirs=new Map(),files=new Map();
 return {name,dirs,files,
  getDirectoryHandle:async(n)=>{if(!dirs.has(n))dirs.set(n,makeDir(n));return dirs.get(n)},
  getFileHandle:async(n)=>{if(!files.has(n))files.set(n,{createWritable:async()=>({write:async data=>{writes.push({name:n,data})},close:async()=>{},abort:async()=>{}})});return files.get(n)},
  queryPermission:async()=> 'granted',requestPermission:async()=> 'granted'
 };
}
const folder=makeDir();const listeners={};
const host={children:[],appendChild(b){this.children.push(b)}};
const document={getElementById:()=>null,querySelector:()=>host,createElement:()=>({addEventListener(event,cb){this.click=cb}}),addEventListener:(name,cb)=>{listeners[name]=cb}};
const window={document,showDirectoryPicker:async()=>folder,
 XLSX:{utils:{book_new:()=>({sheets:[]}),json_to_sheet:x=>x,aoa_to_sheet:x=>x,book_append_sheet:(wb,ws,name)=>wb.sheets.push({name,ws})},write:wb=>JSON.stringify(wb)}
};
vm.runInNewContext(code,{window,document,console,Date,Promise,Error},{filename:'backup-local.js'});
assert.equal(window.sigralBackup.getDir(),null);
await window.sigralBackup.choose();
assert.equal(window.sigralBackup.getDir(),folder);
const model={employees:[{id:1,codigo:'TEST',historial_contratos:[{tipo:'renovacion'}]}],projects:[{id:2}],assignments:[{id:3}]};
const result=await window.sigralBackup.saved(model,'edicion_empleado');
assert.equal(result,true);
assert.equal(writes.length,2);
assert.ok(writes.some(w=>w.name==='SIGRAL_RRHH_Actual.xlsx'));
assert.ok(writes.some(w=>w.name.startsWith('SIGRAL_')));
assert.equal(folder.dirs.get('SIGRAL_RRHH').dirs.size,2);
const book=JSON.parse(writes[0].data);
assert.deepEqual(Array.from(book.sheets,x=>x.name),['Empleados','Proyectos','Asignaciones','Control']);
console.log('OK: respaldo Excel de cuatro hojas, archivo maestro y copia fechada en carpeta seleccionada.');
