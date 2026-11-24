import * as T from 'three';
import {OBJLoader} from 'three/addons/loaders/OBJLoader.js';
import {MTLLoader} from 'three/addons/loaders/MTLLoader.js';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {STLLoader} from 'three/addons/loaders/STLLoader.js';
import {PLYLoader} from 'three/addons/loaders/PLYLoader.js';
import {ThreeMFLoader} from 'three/addons/loaders/3MFLoader.js';
import {USDLoader} from 'three/addons/loaders/USDLoader.js';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
import {STLExporter} from 'three/addons/exporters/STLExporter.js';
import {PLYExporter} from 'three/addons/exporters/PLYExporter.js';
import {USDZExporter} from 'three/addons/exporters/USDZExporter.js';
import {zipSync, unzipSync, strToU8, strFromU8} from 'fflate';

const extOf = url => new URL(url).pathname.split('.').pop().toLowerCase();
const materials = mesh => Array.isArray(mesh.material) ? mesh.material : [mesh.material];
export async function loadModel(url) {
    const ext = extOf(url), manager = new T.LoadingManager();
    const missing = [];
    manager.onError = name => missing.push(name);
    let finish;
    const complete = new Promise(resolve => finish = resolve);
    manager.onLoad = finish;
    manager.itemStart('model');
    const bytes = await new T.FileLoader(manager).setResponseType('arraybuffer').loadAsync(url);
    const base = new URL('.', url).href;
    let model, scale = 1;
    if (ext === 'obj') {
        const text = new TextDecoder().decode(bytes);
        const loader = new OBJLoader(manager);
        const match = /^\s*mtllib\s+(.+?)\s*$/m.exec(text);
        if (match) {
            try {
                const mtl = await new MTLLoader(manager).loadAsync(new URL(match[1].trim(), base).href);
                loader.setMaterials(mtl);
            } catch { missing.push(match[1]); }
        }
        model = loader.parse(text);
    } else if (ext === 'glb' || ext === 'gltf') {
        model = (await new GLTFLoader(manager).parseAsync(bytes, base)).scene;
        scale = 100;
    } else if (ext === 'usdz') {
        model = await new Promise((resolve, reject) => new USDLoader(manager).parse(bytes, base, resolve, reject));
        scale = 100;
    } else if (ext === '3mf') {
        model = new ThreeMFLoader(manager).parse(bytes);
        const files = unzipSync(new Uint8Array(bytes), {filter: f => f.name.toLowerCase().endsWith('.model')});
        const xml = strFromU8(Object.values(files)[0]);
        const unit = /<model\b[^>]*\bunit=["']([^"']+)/i.exec(xml)?.[1] || 'millimeter';
        scale = {micron:0.0001, millimeter:0.1, centimeter:1, inch:2.54, foot:30.48, meter:100}[unit];
        if (!scale) throw Error('Unknown 3MF unit: ' + unit);
        model.rotateX(-Math.PI/2);
    } else {
        const geometry = (ext === 'ply' ? new PLYLoader() : new STLLoader()).parse(bytes);
        if (!geometry.attributes.normal) geometry.computeVertexNormals();
        model = new T.Mesh(geometry, new T.MeshStandardMaterial({vertexColors: !!geometry.attributes.color, side:T.DoubleSide}));
    }
    manager.itemEnd('model');
    await complete;
    const root = new T.Group();
    root.add(model);
    root.scale.setScalar(scale);
    return {root, missing};
}

export function eachTriangle(root, callback) {
    root.updateMatrixWorld(true);
    root.traverse(mesh => {
        if (!mesh.isMesh) return;
        const g = mesh.geometry, positions = g.attributes.position;
        const count = g.index?.count ?? positions.count;
        const points = [new T.Vector3(), new T.Vector3(), new T.Vector3()];
        for (let i = 0; i+2 < count; i += 3) {
            points.forEach((p,j) => p.fromBufferAttribute(positions, g.index ? g.index.getX(i+j) : i+j).applyMatrix4(mesh.matrixWorld));
            callback(...points);
        }
    });
}

function texturePNG(texture) {
    const image = texture.image;
    const canvas = document.createElement('canvas');
    canvas.width = image.width;
    canvas.height = image.height;
    const ctx = canvas.getContext('2d');
    if (!texture.flipY) { ctx.translate(0,canvas.height); ctx.scale(1,-1); }
    ctx.drawImage(image,0,0);
    return canvas.toDataURL('image/png').split(',')[1];
}

function threeMF(root) {
    const vertices = [], faces = [], ids = new Map(), resources = [], relationships = [], files = {};
    const namespace = 'http://schemas.microsoft.com/3dmanufacturing/';
    const vector = new T.Vector3();
    let nextID = 2;
    root.updateMatrixWorld(true);
    root.traverse(mesh => {
        if (!mesh.isMesh) return;
        const g = mesh.geometry, position = g.attributes.position, uv = g.attributes.uv;
        const indices = [];
        for (let k=0; k<position.count; k++) {
            vector.fromBufferAttribute(position,k).applyMatrix4(mesh.matrixWorld);
            const key = vector.toArray().join(' ');
            if (!ids.has(key)) {
                ids.set(key,vertices.length);
                vertices.push(`<vertex x="${vector.x}" y="${-vector.z}" z="${vector.y}"/>`);
            }
            indices.push(ids.get(key));
        }
        for (const group of g.groups.length ? g.groups : [{start:0,count:g.index?.count ?? position.count,materialIndex:0}]) {
            const mat = materials(mesh)[group.materialIndex] ?? materials(mesh)[0];
            const pid = nextID++;
            const textured = !!(mat.map?.image?.width && uv);
            if (textured) {
                const tex = nextID++, path = '3D/Textures/map'+tex+'.png';
                files[path] = Uint8Array.from(atob(texturePNG(mat.map)),c=>c.charCodeAt(0));
                relationships.push(`<Relationship Target="/${path}" Id="r${tex}" Type="${namespace}2013/01/3dtexture"/>`);
                const coords = [];
                for (let i=0; i<uv.count; i++) coords.push(`<m:tex2coord u="${uv.getX(i)}" v="${uv.getY(i)}"/>`);
                resources.push(`<m:texture2d id="${tex}" path="/${path}" contenttype="image/png"/><m:texture2dgroup id="${pid}" texid="${tex}">${coords.join('')}</m:texture2dgroup>`);
            } else {
                const color = mat.color?.getHexString() ?? 'ffffff';
                resources.push(`<basematerials id="${pid}"><base name="material${pid}" displaycolor="#${color}"/></basematerials>`);
            }
            for (let i=group.start; i<group.start+group.count; i+=3) {
                const [a,b,c] = [i,i+1,i+2].map(k=>g.index ? g.index.getX(k) : k);
                faces.push(`<triangle v1="${indices[a]}" v2="${indices[b]}" v3="${indices[c]}" pid="${pid}" p1="${textured?a:0}" p2="${textured?b:0}" p3="${textured?c:0}"/>`);
            }
        }
    });
    const model = `<model unit="centimeter" xml:lang="en-US" xmlns="${namespace}core/2015/02" xmlns:m="${namespace}material/2015/02"><resources>${resources.join('')}<object id="1" type="model"><mesh><vertices>${vertices.join('')}</vertices><triangles>${faces.join('')}</triangles></mesh></object></resources><build><item objectid="1"/></build></model>`;
    const rel = body => strToU8('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'+body+'</Relationships>');
    files['3D/3dmodel.model'] = strToU8(model);
    files['_rels/.rels'] = rel(`<Relationship Target="/3D/3dmodel.model" Id="rel0" Type="${namespace}2013/01/3dmodel"/>`);
    if (relationships.length) files['3D/_rels/3dmodel.model.rels'] = rel(relationships.join(''));
    files['[Content_Types].xml'] = strToU8('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/><Default Extension="png" ContentType="image/png"/></Types>');
    return zipSync(files);
}

function exportOBJ(root) {
    const prefix = 'ipa-'+T.MathUtils.generateUUID(), mtlName = prefix+'.mtl';
    const lines = ['mtllib '+mtlName], mtl = [], assets = {}, ids = new Map();
    let v = 1, vt = 1, vn = 1;
    root.updateMatrixWorld(true);
    root.traverse(mesh => {
        if (!mesh.isMesh) return;
        const g = mesh.geometry, p = g.attributes.position, uv = g.attributes.uv, n = g.attributes.normal;
        const normalMatrix = new T.Matrix3().getNormalMatrix(mesh.matrixWorld);
        const vector = new T.Vector3();
        for (let i=0;i<p.count;i++) lines.push('v '+vector.fromBufferAttribute(p,i).applyMatrix4(mesh.matrixWorld).toArray().join(' '));
        if (uv) for (let i=0;i<uv.count;i++) lines.push('vt '+uv.getX(i)+' '+uv.getY(i));
        if (n) for (let i=0;i<n.count;i++) lines.push('vn '+vector.fromBufferAttribute(n,i).applyNormalMatrix(normalMatrix).toArray().join(' '));
        for (const group of g.groups.length ? g.groups : [{start:0,count:g.index?.count ?? p.count,materialIndex:0}]) {
            const mat = materials(mesh)[group.materialIndex] ?? materials(mesh)[0];
            if (!ids.has(mat)) {
                const id = 'material'+ids.size;
                ids.set(mat,id);
                mtl.push('newmtl '+id, 'Kd '+(mat.color ?? new T.Color(1,1,1)).toArray().join(' '), 'd '+mat.opacity);
                for (const [slot,key] of [['map','map_Kd'],['normalMap','norm'],['alphaMap','map_d']]) {
                    const tex = mat[slot], img = tex?.image;
                    if (!img?.width) continue;
                    const filename = prefix+'-'+id+'-'+slot+'.png';
                    assets[filename] = texturePNG(tex);
                    mtl.push(key+' '+filename);
                }
            }
            lines.push('usemtl '+ids.get(mat));
            for (let i=group.start;i<group.start+group.count;i+=3) {
                const face = [0,1,2].map(j => {
                    const k = g.index ? g.index.getX(i+j) : i+j;
                    return (v+k)+(uv||n ? '/'+(uv ? vt+k : '') : '')+(n ? '/'+(vn+k) : '');
                });
                lines.push('f '+face.join(' '));
            }
        }
        v += p.count; vt += uv?.count ?? 0; vn += n?.count ?? 0;
    });
    assets[mtlName] = btoa(mtl.join('\n'));
    return {data:lines.join('\n'), assets};
}

export async function exportModel(root, ext) {
    const scene = new T.Scene();
    const copy = root.clone();
    if (['glb','gltf','usdz'].includes(ext)) copy.scale.multiplyScalar(0.01);
    scene.add(copy);
    scene.updateMatrixWorld(true);
    if (ext === 'obj') return exportOBJ(scene);
    let data;
    if (ext === '3mf') data = threeMF(scene);
    if (ext === 'stl') data = new STLExporter().parse(scene,{binary:true}).buffer;
    if (ext === 'ply') data = new PLYExporter().parse(scene,null,{binary:true,littleEndian:true});
    if (ext === 'usdz') data = await new USDZExporter().parseAsync(scene);
    if (ext === 'glb' || ext === 'gltf') {
        data = await new GLTFExporter().parseAsync(scene,{binary:ext === 'glb'});
        if (ext === 'gltf') data = JSON.stringify(data);
    }
    return {data};
}
