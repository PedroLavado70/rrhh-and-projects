/* SIGRAL RRHH: copia Excel bajo control del usuario (Chrome/Edge, HTTPS).
   No se transmite nada a servicios externos. NO equivale a respaldo transaccional. */
(function(){
 'use strict';
 let folder=null, saving=Promise.resolve(),lastResult='';
 const dateTag=()=>new Date().toISOString().replace(/[:.]/g,'-');
 const safe=(x)=>String(x||'actualizacion').replace(/[^a-z0-9_-]/gi,'_').slice(0,36);
 function getDir(){return folder;}
 async function ensureSubfolder(parent,name){return parent.getDirectoryHandle(name,{create:true});}
 async function fileBytes(model,reason){
   if(!window.XLSX)throw new Error('No disponible el módulo XLSX');
   const wb=XLSX.utils.book_new();
   const lists=[
     ['Empleados',model.employees||[]],['Proyectos',model.projects||[]],
     ['Asignaciones',model.assignments||[]]
   ];
   for(const [name,records] of lists){
     const arr=records.map(r=>({...r,historial:JSON.stringify(r.historial||[]),historial_contratos:JSON.stringify(r.historial_contratos||[])}));
     const sh=XLSX.utils.json_to_sheet(arr.length?arr:[{aviso:'Sin registros'}]);
     XLSX.utils.book_append_sheet(wb,sh,name);
   }
   const meta=XLSX.utils.aoa_to_sheet([
     ['SIGRAL RRHH','Exportación de consulta — NO restituye toda la BD'],
     ['Fecha UTC',new Date().toISOString()],['Motivo',reason],
     ['Empleados',(model.employees||[]).length],['Proyectos',(model.projects||[]).length],
     ['Asignaciones',(model.assignments||[]).length]
   ]);
   XLSX.utils.book_append_sheet(wb,meta,'Control');
   return XLSX.write(wb,{bookType:'xlsx',type:'array'});
 }
 async function write(handle,bytes){const writable=await handle.createWritable();try{await writable.write(bytes);await writable.close()}catch(e){try{await writable.abort()}catch{}throw e}}
 async function saveNow(model,reason){
   if(!folder)return false;
   const permission=await folder.queryPermission({mode:'readwrite'});
   if(permission!=='granted')throw new Error('Permiso de carpeta caducado. Selecciona la carpeta nuevamente');
   const bytes=await fileBytes(model,reason);
   const root=await ensureSubfolder(folder,'SIGRAL_RRHH');
   const master=await ensureSubfolder(root,'01_BASE_MAESTRA');
   const versions=await ensureSubfolder(root,'02_RESPALDOS');
   const tag=dateTag(),name='SIGRAL_'+tag+'_'+safe(reason)+'.xlsx';
   // Copia inmutable primero, para que una interrupción no destruya el respaldo anterior.
   await write(await versions.getFileHandle(name,{create:true}),bytes);
   await write(await master.getFileHandle('SIGRAL_RRHH_Actual.xlsx',{create:true}),bytes);
   lastResult=tag;
   return true;
 }
 function notify(message,kind='s'){if(typeof window.toast==='function')window.toast(message,kind);else console.info(message)}
 async function choose(){
   if(typeof window.showDirectoryPicker!=='function'){
     notify('Esta función requiere Chrome o Edge compatible en HTTPS. Puedes seguir exportando Excel manualmente.','w');return;
   }
   try{
     folder=await window.showDirectoryPicker({id:'sigral-rrhh-backups',mode:'readwrite'});
     if(await folder.requestPermission({mode:'readwrite'})!=='granted'){folder=null;notify('Permiso de carpeta no autorizado.','w');return}
     notify('Carpeta de respaldo vinculada en esta sesión. Se guardará un Excel tras cada modificación.','s');
   }catch(e){if(e.name!=='AbortError')notify('No se pudo seleccionar la carpeta: '+e.message,'w')}
 }
 function saved(model,reason){
   if(!folder)return Promise.resolve(false);
   const run=()=>saveNow(model,reason);
   const p=saving.then(run,run);
   saving=p.then(()=>{},()=>{});
   p.catch(e=>notify('Modificación guardada en Supabase, pero FALLÓ el respaldo Excel: '+e.message,'d'));
   return p;
 }
 function addButton(){
   if(document.getElementById('sigral-local-folder'))return;
   const host=document.querySelector('.tb .pb');if(!host)return;
   const b=document.createElement('button');b.id='sigral-local-folder';
   b.type='button';b.className='pbb';b.textContent='📁 Vincular carpeta Excel';
   b.title='Habilita respaldo Excel local después de cada modificación confirmada';
   b.addEventListener('click',choose);host.appendChild(b);
 }
 document.addEventListener('DOMContentLoaded',addButton);
 window.sigralBackup={choose,saved,getDir,lastResult:()=>lastResult,createExcel:fileBytes};
})();