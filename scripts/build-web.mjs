import {cp,mkdir,rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const root=new URL('../',import.meta.url),destination=new URL('docs/play/',root);
await rm(destination,{recursive:true,force:true});await mkdir(destination,{recursive:true});
await cp(new URL('web/',root),destination,{recursive:true});
console.log(`Built web garden at ${fileURLToPath(destination)}`);
