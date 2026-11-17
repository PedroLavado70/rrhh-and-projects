import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const src=fs.readFileSync('scripts/operational-dashboard.js','utf8');
const context={window:{},document:{},Date,Set,Map,Math};
vm.runInNewContext(src,context);
const {evaluate,daysUntil}=context.window.sigralOperational;
const now=new Date('2026-11-16T12:00:00');
assert.equal(daysUntil('2026-11-16',now),0);
assert.equal(daysUntil('2026-11-17',now),1);
const x=evaluate({employees:[
 {id:1,nombres:'Ana',apellidos:'Prueba',estado:'Activo',tipo_contrato:'Indefinido',fecha_fin_contrato:''},
 {id:2,nombres:'Leo',apellidos:'Prueba',estado:'Activo',tipo_contrato:'Plazo Fijo',fecha_fin_contrato:'2026-11-30'},
 {id:3,nombres:'Fin',estado:'Cesado',tipo_contrato:'Plazo Fijo',fecha_fin_contrato:'2026-11-18'}
],projects:[
 {id:1,codigo:'10101',nombre:'Activo',estado:'En curso',fecha_fin:'2026-11-28'},
 {id:2,codigo:'20202',nombre:'Terminado',estado:'Concluido',fecha_fin:'2026-11-20'}
],assignments:[
 {id:1,empleado_id:1,proyecto_id:1,fecha_fin:'2026-11-22',pct:100},
 {id:2,empleado_id:3,proyecto_id:1,fecha_fin:'2026-11-20',pct:100},
 {id:3,empleado_id:2,proyecto_id:2,fecha_fin:'2026-11-20',pct:100}
]},now);
assert.equal(x.due.length,1);
assert.equal(x.expiring.length,1);
assert.equal(x.ending.length,1);
assert.equal(x.ending[0].id,1);
console.log('OK: cierres y alertas de contratos y recursos por liberar sin falsos positivos.');
