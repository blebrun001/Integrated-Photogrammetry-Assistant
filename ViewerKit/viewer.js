import * as T from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {loadModel, exportModel} from './formats.js';
import {illustrate} from './illustration.js';

const el = id => document.getElementById(id);
const t = key => window.ipaStrings?.[key] ?? key;
for (const option of document.querySelectorAll('option')) option.value = option.value;
const walker = document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
while (walker.nextNode()) {
    const node = walker.currentNode, key = node.nodeValue.trim();
    if (key && node.parentElement.tagName !== 'SCRIPT') node.nodeValue = node.nodeValue.replace(key,t(key));
}
const status = text => el('status').textContent = t(text);
const bridge = info => window.webkit.messageHandlers.ipa.postMessage(info);
const canvas = el('viewport');
const renderer = new T.WebGLRenderer({canvas,antialias:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,2));
const scene = new T.Scene();
scene.background = new T.Color(0x383d43);
const camera = new T.PerspectiveCamera(38,1,0.01,10000);
const orbit = new OrbitControls(camera,canvas);
const ray = new T.Raycaster();
function render() { renderer.render(scene,camera); }
orbit.addEventListener('change',render);
const fill = new T.HemisphereLight(0xffffff,0xaaaab0,2.4);
const key = new T.DirectionalLight(0xffffff,2);
key.position.set(2,3,4);
scene.add(fill,key);
const wire = new T.MeshBasicMaterial({wireframe:true,color:0xbcc6d0});
const solid = new T.MeshStandardMaterial({color:0xb3afa7,side:T.DoubleSide});
const overlay = new T.MeshBasicMaterial({wireframe:true,color:0x222222,transparent:true,opacity:0.45,depthWrite:false});
let model, loadID = 0, calibrated = '', references = [], picks = [], saved = [], drag;
let materials = new Map(), lines = [];
const dotMaterial = new T.MeshBasicMaterial({color:0xffa900,depthTest:false});
let dots = [];

function frame() {
    const box = new T.Box3().setFromObject(model,true);
    const size = Math.max(box.getSize(new T.Vector3()).length(),0.000001);
    const center = box.getCenter(new T.Vector3());
    if (!Number.isFinite(size) || box.isEmpty()) throw Error('The model contains no visible geometry.');
    orbit.target.copy(center);
    camera.near = size/10000; camera.far = size*1000;
    camera.position.copy(center).addScaledVector(new T.Vector3(1,0.7,1).normalize(),size*1.65);
    camera.updateProjectionMatrix(); orbit.update();
}
function style(mode) {
    for (const line of lines) line.removeFromParent();
    lines = [];
    for (const [mesh,mat] of materials) {
        mesh.material = mode === 'Solid' ? solid : mode === 'Wireframe' ? wire : mat;
        if (mode === 'Texture + wireframe') {
            const line = new T.Mesh(mesh.geometry,overlay);
            mesh.add(line); lines.push(line);
        }
    }
}
function clearPicks() {
    picks = [];
    for (const dot of dots) { dot.removeFromParent(); dot.geometry.dispose(); }
    dots = [];
    render();
}
function sync() {
    render();
    el('calibration').textContent = calibrated ? t('Calibrated')+' · '+t(calibrated) : t('Uncalibrated');
    el('bar').disabled = !calibrated;
    el('reference').hidden = el('tool').value !== 'Calibrate';
    orbit.enabled = el('tool').value === 'Orbit camera';
    el('count').textContent = references.length+' '+t('reference(s)');
    el('apply').disabled = !references.length;
    el('add').disabled = picks.length !== 2;
    el('undo').disabled = !saved.length;
    for (const axis of ['x','y','z']) el(axis).value = +(model.rotation[axis]*180/Math.PI).toFixed(3);
}
function snapshot() {
    saved.push({rotation:model.rotation.clone(),scale:model.scale.clone(),calibrated});
}
function restoreDisplay(action) {
    style('Texture');
    return Promise.resolve().then(action).finally(()=>style(el('display').value));
}
for (const axis of ['x','y','z']) {
    const label = document.createElement('label');
    label.textContent = axis.toUpperCase()+' ';
    const input = document.createElement('input'); input.type = 'number'; input.id = axis; input.step = 'any';
    input.onchange = () => {
        if (!Number.isFinite(input.valueAsNumber)) return;
        snapshot(); model.rotation[axis] = input.valueAsNumber*Math.PI/180;
        clearPicks(); sync(); frame();
    };
    label.appendChild(input); el('axes').appendChild(label);
}
for (const ext of ['obj','glb','gltf','ply','stl','usdz','3mf']) el('format').add(new Option(ext.toUpperCase(),ext));
el('display').onchange = () => { style(el('display').value); render(); };
el('tool').onchange = () => {
    clearPicks(); sync();
    el('hint').textContent = t({'Measure distance':'Click two surface points.',Calibrate:'Click two points, then add their known distance.', 'Rotate model':'Drag to rotate the model.'}[el('tool').value] || '');
};
el('doc').onchange = () => el('sliceLabel').hidden = el('doc').value !== 'Cross section';
window.ipaOpen = async (url, automatic) => {
    const token = ++loadID;
    status('Loading model…'); el('panel').hidden = true;
    try {
        const loaded = await loadModel(url);
        if (token !== loadID) return;
        style('Texture');
        if (model) {
            model.removeFromParent();
            model.traverse(mesh=>{
                mesh.geometry?.dispose();
                for (const mat of [].concat(mesh.material || [])) {
                    for (const value of Object.values(mat)) if (value?.isTexture) value.dispose();
                    mat.dispose();
                }
            });
        }
        model = new T.Group(); model.add(loaded.root);
        materials = new Map();
        model.traverse(mesh=>{ if (mesh.isMesh) materials.set(mesh,mesh.material); });
        if (!materials.size) throw Error('No mesh found in the model.');
        scene.add(model); frame();
        clearPicks(); references = []; saved = []; calibrated = automatic ? 'Auto Scale' : '';
        el('tool').value = 'Orbit camera'; el('tool').onchange();
        el('format').value = new URL(url).pathname.split('.').pop().toLowerCase();
        style(el('display').value); el('panel').hidden = false; render();
        status(loaded.missing.length ? 'Missing model resources: '+loaded.missing.join(', ') : 'Model loaded.');
    } catch (error) { if (token === loadID) status(error.message); }
};
canvas.addEventListener('pointerdown', e=>{
    if (!model || el('tool').value === 'Orbit camera') return;
    if (el('tool').value === 'Rotate model') {
        snapshot(); drag = [e.clientX,e.clientY]; canvas.setPointerCapture(e.pointerId); return;
    }
    const r = canvas.getBoundingClientRect();
    ray.setFromCamera(new T.Vector2((e.clientX-r.left)/r.width*2-1,1-(e.clientY-r.top)/r.height*2),camera);
    const hit = ray.intersectObjects([...materials.keys()],false)[0];
    if (!hit) return;
    if (picks.length === 2) clearPicks();
    picks.push(hit.point.clone());
    const dot = new T.Mesh(new T.SphereGeometry(camera.position.distanceTo(orbit.target)/260,10,8),dotMaterial);
    dot.position.copy(hit.point); scene.add(dot); dots.push(dot);
    if (picks.length === 2) {
        const d = picks[0].distanceTo(picks[1]);
        status(calibrated ? d.toLocaleString(undefined,{maximumSignificantDigits:6})+' cm' : 'Two points selected · calibration required for cm.');
    }
    sync();
});
canvas.addEventListener('pointermove', e=>{
    if (!drag) return;
    model.rotateOnWorldAxis(new T.Vector3(0,1,0),(e.clientX-drag[0])/120);
    model.rotateOnWorldAxis(new T.Vector3(1,0,0),(e.clientY-drag[1])/120);
    drag = [e.clientX,e.clientY]; sync();
});
canvas.addEventListener('lostpointercapture',()=>drag=null);
el('add').onclick = () => {
    const cm = el('length').valueAsNumber, measured = picks[0].distanceTo(picks[1]);
    if (!(cm>0 && measured>0)) return status('Enter a positive distance and choose distinct points.');
    references.push(cm/measured); clearPicks(); sync();
};
el('apply').onclick = async () => {
    if (calibrated === 'Auto Scale' && !await bridge({action:'confirm',text:t('Replace automatic calibration with these manual references?')})) return;
    snapshot();
    model.scale.multiplyScalar(references.reduce((a,b)=>a+b,0)/references.length);
    references = []; calibrated = 'Manual'; clearPicks(); sync(); frame(); status('Manual calibration applied.');
};
el('undo').onclick = () => {
    const last = saved.pop(); model.rotation.copy(last.rotation); model.scale.copy(last.scale);
    calibrated = last.calibrated; references=[]; clearPicks(); sync(); frame();
};
const warnings = {
    obj:'OBJ stores unitless coordinates. IPA writes centimetres, MTL and available diffuse, alpha and normal maps. PBR properties and hierarchy may change.',
    ply:'PLY stores numeric coordinates in centimetres. Image textures, material assignments and hierarchy will be lost.',
    stl:'STL stores only triangles and normals. IPA writes unitless coordinates in centimetres. Set the receiving unit accordingly.',
    '3mf':'3MF stores this mesh in centimetres. Components are flattened. Base colors and diffuse textures are retained; other material properties may change.',
    glb:'glTF uses metres. Materials are converted to glTF PBR. Unsupported shader properties may change.',
    gltf:'glTF uses metres. Materials are converted to glTF PBR. Unsupported shader properties may change.',
    usdz:'USDZ uses metres. Materials are converted to USD Preview Surface. Unsupported shader properties may change.'
};
el('save').onclick = async () => {
    const ext = el('format').value;
    if (!await bridge({action:'confirm',text:t(warnings[ext])+' '+t('Choose the original filename to replace it, or a new filename to keep both.')})) return;
    try {
        const {data, assets} = await restoreDisplay(()=>exportModel(model,ext));
        const base64 = await new Promise((resolve,reject)=>{
            const reader = new FileReader(); reader.onload = ()=>resolve(reader.result.split(',')[1]);
            reader.onerror = reject; reader.readAsDataURL(new Blob([data]));
        });
        if (await bridge({action:'save',ext,data:base64,assets:assets||{}})) status('Model saved.');
    } catch (error) { status(String(error)); }
};
el('illustrate').onclick = async () => {
    try {
        const data = await restoreDisplay(()=>illustrate(model,el('doc').value,el('direction').value,+el('slice').value/100,calibrated && el('bar').checked));
        if (await bridge({action:'save',ext:'png',data})) status('Illustration saved.');
    } catch (error) { status(String(error)); }
};
new ResizeObserver(()=>{
    const {width,height} = canvas.getBoundingClientRect();
    if (!width || !height) return;
    renderer.setSize(width,height,false); camera.aspect = width/height; camera.updateProjectionMatrix(); render();
}).observe(canvas);

bridge({action:'ready'});
