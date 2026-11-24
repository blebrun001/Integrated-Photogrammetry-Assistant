const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright-core');

test('viewer calibration, orientation, dimensional round trips and illustrations', async t => {
    const resources = path.join(__dirname,'../IPA/Modules/3D creation/Viewer/Resources');
    const files = new Map([
        ['/test.obj','mtllib test.mtl\nv -1 -1 0\nv 1 -1 0\nv 1 1 0\nv -1 1 0\nvt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\nusemtl clay\nf 1/1 2/2 3/3\nf 1/1 3/3 4/4\n'],
        ['/test.mtl','newmtl clay\nKd 1 1 1\nmap_Kd texture.png\n'],
        ['/texture.png',Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jLn0AAAAASUVORK5CYII=','base64')]
    ]);
    const server = http.createServer((req,res) => {
        if (files.has(req.url)) return res.end(files.get(req.url));
        if (['/viewer.html','/viewer.js'].includes(req.url)) {
            res.setHeader('Content-Type',req.url.endsWith('js') ? 'text/javascript' : 'text/html');
            return res.end(fs.readFileSync(path.join(resources,req.url)));
        }
        res.statusCode = 404; res.end();
    });
    await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
    t.after(()=>server.close());
    const base = 'http://127.0.0.1:'+server.address().port;
    const browser = await chromium.launch({executablePath:process.env.CHROME_PATH || undefined,
        args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
    t.after(()=>browser.close());
    const page = await browser.newPage();
    let lastSave;
    const confirmations = [];
    await page.exposeFunction('viewerMessage',message=>{
        if (message.action === 'confirm') confirmations.push(message.text);
        if (message.action === 'save') {
            lastSave = message;
            files.set('/saved.'+message.ext,Buffer.from(message.data,'base64'));
            for (const [name,value] of Object.entries(message.assets || {})) files.set('/'+name,Buffer.from(value,'base64'));
        }
        return true;
    });
    await page.addInitScript(()=>window.webkit={messageHandlers:{ipa:{postMessage:info=>window.viewerMessage(info)}}});
    await page.goto(base+'/viewer.html');
    const open = async name => {
        await page.evaluate(async url=>await window.ipaOpen(url,true),base+'/'+name);
        assert.equal(await page.locator('#status').textContent(),'Model loaded.');
    };
    const save = async ext => {
        await page.selectOption('#format',ext);
        await page.evaluate(()=>document.querySelector('#save').onclick());
        assert.equal(await page.locator('#status').textContent(),'Model saved.');
        assert.equal(lastSave.ext,ext);
    };
    const bounds = () => {
        const verts = files.get('/saved.obj').toString().split('\n').filter(l=>l.startsWith('v ')).map(l=>l.split(' ').slice(1).map(Number));
        return [0,1,2].map(i=>Math.max(...verts.map(v=>v[i]))-Math.min(...verts.map(v=>v[i])));
    };
    for (const ext of ['obj','glb','gltf','ply','stl','usdz','3mf']) {
        await open('test.obj');
        await save(ext);
        await open('saved.'+ext);
        await save('obj');
        const dims = bounds();
        assert(dims.every((value,i)=>Math.abs(value-[2,2,0][i])<1e-4),ext+' dimensions '+dims);
        if (!['ply','stl'].includes(ext)) assert(Object.keys(lastSave.assets).some(k=>k.endsWith('.png')),ext+' diffuse texture');
    }

    await open('test.obj');
    await page.evaluate(() => window.ipaManualMode(true));
    assert.equal(await page.locator('#panel').isVisible(), true);
    const rect = await page.locator('canvas').boundingBox();
    const click = dx=>page.mouse.click(rect.x+rect.width/2+dx,rect.y+rect.height/2);
    for (const cm of [2,4]) {
        await click(-15); await click(15);
        await page.evaluate(value => window.ipaManualAdd(value), cm);
    }
    assert.match(await page.locator('#count').textContent(),/^2 /);
    await page.evaluate(() => window.ipaManualApply());
    await page.evaluate(() => window.ipaManualMode(false));
    assert(confirmations.some(s=>s.includes('Replace automatic calibration')));
    assert.equal(await page.locator('#calibration').textContent(),'Calibrated · Manual');
    await save('obj'); assert(bounds()[0]>2);
    await page.click('#undo'); await save('obj'); assert.equal(bounds()[0],2);
    await page.fill('#y','90'); await page.locator('#y').press('Tab');
    await save('obj'); assert(Math.abs(bounds()[2]-2)<1e-6);
    await page.selectOption('#tool','Rotate model');
    await page.mouse.move(rect.width/2,rect.height/2); await page.mouse.down();
    await page.mouse.move(rect.width/2+80,rect.height/2+30); await page.mouse.up();
    await save('obj'); assert(bounds()[0]>0.1);

    await open('test.obj');
    for (const mode of ['Orthographic view','Multiview plate','Cross section','Silhouette','Profile']) {
        await page.selectOption('#doc',mode);
        await page.evaluate(()=>document.querySelector('#illustrate').onclick());
        assert.equal(lastSave.ext,'png');
        const png = files.get('/saved.png');
        assert.equal(png.readUInt32BE(16),mode === 'Multiview plate' ? 3600 : 1200);
        const barPixels = await page.evaluate(async base64=>{
            const img = new Image(); img.src = 'data:image/png;base64,'+base64; await img.decode();
            const canvas = document.createElement('canvas'); canvas.width = img.width; canvas.height = img.height;
            const ctx = canvas.getContext('2d'); ctx.drawImage(img,0,0);
            const row = ctx.getImageData(32,1167,300,1).data;
            let width = 0;
            while (width < 300 && row[width*4]<128) width++;
            return width;
        },lastSave.data);
        // A 0.5 cm bar with a square of side 2 cm in a 1.12-diagonal orthographic field.
        assert(Math.abs(barPixels-0.5*1200/(Math.sqrt(8)*1.12))<1,mode+' scale bar');
    }
});
