// Three.js Energy Wave Background with Lightning

let scene, camera, renderer, energyWaves = [], particles, lightningBolts = [];

function initThreeJS() {
    const container = document.getElementById('canvas-container');
    
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.z = 50;
    camera.position.y = 10;
    
    renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(window.devicePixelRatio);
    container.appendChild(renderer.domElement);
    
    // Create energy sine waves (flowing lines)
    const waveCount = 8;
    for(let i = 0; i < waveCount; i++) {
        const points = [];
        const segments = 100;
        const amplitude = 5 + Math.random() * 5;
        const frequency = 0.1 + Math.random() * 0.1;
        const yOffset = (i - waveCount/2) * 8;
        
        for(let j = 0; j <= segments; j++) {
            const x = (j / segments) * 100 - 50;
            const y = yOffset + Math.sin(x * frequency) * amplitude;
            const z = Math.cos(x * frequency * 0.5) * 5;
            points.push(new THREE.Vector3(x, y, z));
        }
        
        const geometry = new THREE.BufferGeometry().setFromPoints(points);
        const material = new THREE.LineBasicMaterial({
            color: i % 2 === 0 ? 0x00ffc8 : 0x00d4ff,
            transparent: true,
            opacity: 0.4 + Math.random() * 0.3,
            linewidth: 2
        });
        
        const wave = new THREE.Line(geometry, material);
        wave.userData = {
            originalPoints: points.map(p => p.clone()),
            phase: Math.random() * Math.PI * 2,
            speed: 0.5 + Math.random() * 0.5,
            amplitude: amplitude,
            frequency: frequency
        };
        energyWaves.push(wave);
        scene.add(wave);
    }
    
    // Create energy particles flowing along waves
    const particleCount = 200;
    const particleGeometry = new THREE.BufferGeometry();
    const positions = new Float32Array(particleCount * 3);
    const colors = new Float32Array(particleCount * 3);
    
    for(let i = 0; i < particleCount; i++) {
        const waveIndex = Math.floor(Math.random() * waveCount);
        const t = Math.random();
        const wave = energyWaves[waveIndex];
        const point = wave.userData.originalPoints[Math.floor(t * 99)];
        
        positions[i * 3] = point.x + (Math.random() - 0.5) * 2;
        positions[i * 3 + 1] = point.y + (Math.random() - 0.5) * 2;
        positions[i * 3 + 2] = point.z + (Math.random() - 0.5) * 2;
        
        const colorChoice = Math.random();
        if(colorChoice < 0.33) {
            colors[i * 3] = 0; colors[i * 3 + 1] = 1; colors[i * 3 + 2] = 0.78; // Emerald
        } else if(colorChoice < 0.66) {
            colors[i * 3] = 0; colors[i * 3 + 1] = 0.83; colors[i * 3 + 2] = 1; // Cyan
        } else {
            colors[i * 3] = 0; colors[i * 3 + 1] = 0.6; colors[i * 3 + 2] = 1; // Blue
        }
    }
    
    particleGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    particleGeometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
    
    const particleMaterial = new THREE.PointsMaterial({
        size: 0.8,
        vertexColors: true,
        transparent: true,
        opacity: 0.8,
        blending: THREE.AdditiveBlending
    });
    
    particles = new THREE.Points(particleGeometry, particleMaterial);
    scene.add(particles);
    
    // Lightning bolts (electric arcs)
    for(let i = 0; i < 3; i++) {
        const boltGeometry = new THREE.BufferGeometry();
        const boltPoints = [];
        let currentX = -40 + Math.random() * 20;
        let currentY = -20 + Math.random() * 40;
        
        for(let j = 0; j < 20; j++) {
            boltPoints.push(new THREE.Vector3(currentX, currentY, 0));
            currentX += 4;
            currentY += (Math.random() - 0.5) * 10;
        }
        
        boltGeometry.setFromPoints(boltPoints);
        const boltMaterial = new THREE.LineBasicMaterial({
            color: 0x00ffff,
            transparent: true,
            opacity: 0
        });
        
        const bolt = new THREE.Line(boltGeometry, boltMaterial);
        bolt.userData = { active: false, timer: Math.random() * 100 };
        lightningBolts.push(bolt);
        scene.add(bolt);
    }
    
    // Grid floor
    const gridHelper = new THREE.GridHelper(100, 50, 0x00ffc8, 0x003333);
    gridHelper.position.y = -30;
    gridHelper.material.transparent = true;
    gridHelper.material.opacity = 0.2;
    scene.add(gridHelper);
    
    animate();
}

function animate() {
    requestAnimationFrame(animate);
    
    const time = Date.now() * 0.001;
    
    // Animate energy waves
    energyWaves.forEach((wave, index) => {
        const positions = wave.geometry.attributes.position.array;
        const originalPoints = wave.userData.originalPoints;
        const phase = wave.userData.phase;
        const speed = wave.userData.speed;
        
        for(let i = 0; i < originalPoints.length; i++) {
            const original = originalPoints[i];
            const offset = Math.sin(time * speed + original.x * 0.1 + phase) * 2;
            
            positions[i * 3] = original.x;
            positions[i * 3 + 1] = original.y + offset;
            positions[i * 3 + 2] = original.z + Math.cos(time * speed + original.x * 0.05) * 2;
        }
        
        wave.geometry.attributes.position.needsUpdate = true;
    });
    
    // Animate particles
    if(particles) {
        const positions = particles.geometry.attributes.position.array;
        for(let i = 0; i < positions.length; i += 3) {
            positions[i] += Math.sin(time + i) * 0.02;
            positions[i + 1] += Math.cos(time + i * 0.5) * 0.02;
        }
        particles.geometry.attributes.position.needsUpdate = true;
        particles.rotation.y = time * 0.05;
    }
    
    // Animate lightning
    lightningBolts.forEach(bolt => {
        bolt.userData.timer--;
        if(bolt.userData.timer <= 0) {
            bolt.userData.active = !bolt.userData.active;
            bolt.userData.timer = bolt.userData.active ? 5 : 100 + Math.random() * 200;
            bolt.material.opacity = bolt.userData.active ? 0.8 : 0;
            
            if(bolt.userData.active) {
                // Randomize bolt path
                const positions = bolt.geometry.attributes.position.array;
                let currentY = positions[1];
                for(let i = 3; i < positions.length; i += 3) {
                    positions[i + 1] = currentY + (Math.random() - 0.5) * 15;
                    currentY = positions[i + 1];
                }
                bolt.geometry.attributes.position.needsUpdate = true;
            }
        }
    });
    
    // Camera gentle movement
    camera.position.x = Math.sin(time * 0.1) * 5;
    camera.lookAt(0, 0, 0);
    
    renderer.render(scene, camera);
}

window.addEventListener('resize', () => {
    if (!camera || !renderer) return;
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
});