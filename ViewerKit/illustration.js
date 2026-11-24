import * as T from 'three';
import {eachTriangle} from './formats.js';

const directions = {Front:[0,0,1], Side:[1,0,0], Top:[0,1,0]};
export function illustrate(root, mode, direction, fraction, calibrated) {
    const views = mode === 'Multiview plate' ? Object.keys(directions) : [direction];
    const width = 1200, height = 1200;
    const sheet = document.createElement('canvas');
    sheet.width = width * views.length; sheet.height = height;
    const ctx = sheet.getContext('2d');
    ctx.fillStyle = 'white'; ctx.fillRect(0,0,sheet.width,height);
    const box = new T.Box3().setFromObject(root,true);
    const center = box.getCenter(new T.Vector3());
    const span = box.getSize(new T.Vector3()).length() * 1.12;
    const renderer = new T.WebGLRenderer({antialias:true,preserveDrawingBuffer:true});
    renderer.setSize(width,height,false);
    const scene = new T.Scene();
    scene.background = new T.Color('white');
    const copy = root.clone();
    scene.add(copy,new T.HemisphereLight(0xffffff,0x888888,2));
    const light = new T.DirectionalLight(0xffffff,2);
    light.position.set(2,4,3); scene.add(light);
    const ink = new T.MeshBasicMaterial({color:0x171717,side:T.DoubleSide});
    if (mode === 'Silhouette' || mode === 'Profile') scene.overrideMaterial = ink;
    try {
        views.forEach((view,index) => {
            const axis = new T.Vector3(...directions[view]);
            const camera = new T.OrthographicCamera(-span/2,span/2,span/2,-span/2,span*0.001,span*5);
            camera.position.copy(center).addScaledVector(axis,span*2);
            if (view === 'Top') camera.up.set(0,0,-1);
            camera.lookAt(center); camera.updateMatrixWorld();
            ctx.save(); ctx.translate(index*width,0);
            if (mode === 'Cross section') {
                const plane = axis.dot(box.min)+(axis.dot(box.max)-axis.dot(box.min))*fraction;
                ctx.strokeStyle = '#151515'; ctx.lineWidth = 1.5; ctx.beginPath();
                eachTriangle(root,(a,b,c) => {
                    const hits = [];
                    for (const [p,q] of [[a,b],[b,c],[c,a]]) {
                        const d = axis.dot(p)-plane, e = axis.dot(q)-plane;
                        if ((d<0) !== (e<0)) hits.push(p.clone().lerp(q,d/(d-e)).project(camera));
                    }
                    if (hits.length === 2) {
                        ctx.moveTo((hits[0].x+1)*width/2,(1-hits[0].y)*height/2);
                        ctx.lineTo((hits[1].x+1)*width/2,(1-hits[1].y)*height/2);
                    }
                });
                ctx.stroke();
            } else {
                renderer.render(scene,camera);
                ctx.drawImage(renderer.domElement,0,0);
                if (mode === 'Profile') {
                    const pixels = ctx.getImageData(index*width,0,width,height);
                    const input = new Uint8ClampedArray(pixels.data);
                    for (let y=1;y<height-1;y++) for (let x=1;x<width-1;x++) {
                        const i = 4*(y*width+x);
                        const edge = input[i]<128 && [4,-4,4*width,-4*width].some(offset=>input[i+offset]>=128);
                        pixels.data.fill(edge ? 20 : 255,i,i+3);
                    }
                    ctx.putImageData(pixels,index*width,0);
                }
            }
            ctx.fillStyle = '#161616'; ctx.font = '24px sans-serif';
            ctx.fillText(view,24,36);
            if (calibrated) {
                const base = 10**Math.floor(Math.log10(span/5));
                const cm = [5,2,1].map(n=>n*base).find(n=>n<=span/5);
                ctx.fillRect(32,height-35,cm*width/span,5);
                ctx.fillText(cm.toPrecision(2)+' cm',32,height-46);
            }
            ctx.restore();
        });
        return sheet.toDataURL('image/png').split(',')[1];
    } finally { renderer.dispose(); renderer.forceContextLoss(); ink.dispose(); }
}
