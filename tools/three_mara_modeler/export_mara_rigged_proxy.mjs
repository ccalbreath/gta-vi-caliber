import { writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import * as THREE from "three";
import { GLTFExporter } from "three/examples/jsm/exporters/GLTFExporter.js";

globalThis.FileReader = class {
	constructor() {
		this.result = null;
		this.onloadend = null;
	}

	readAsArrayBuffer(blob) {
		blob.arrayBuffer().then((buffer) => {
			this.result = buffer;
			this.onloadend?.();
		});
	}

	readAsDataURL(blob) {
		blob.arrayBuffer().then((buffer) => {
			const base64 = Buffer.from(buffer).toString("base64");
			this.result = `data:${blob.type || "application/octet-stream"};base64,${base64}`;
			this.onloadend?.();
		});
	}
};

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "../..");
const outputPath = resolve(repoRoot, "game/assets/characters/mara_three_rigged_proxy.glb");

const scene = new THREE.Scene();
scene.name = "mara_three_rigged_proxy";

const materials = {
	skin: material("mara_rigged_skin", 0xffc49a, 0.46, 0.0, 0.08),
	jacket: material("mara_rigged_clearcoat_jacket", 0x1f2729, 0.44, 0.0, 0.3),
	jacketTrim: material("mara_rigged_jacket_trim", 0x0b0d0e, 0.38, 0.0, 0.36),
	shirt: material("mara_rigged_layered_shirt", 0xd8d0c2, 0.74, 0.0, 0.0),
	fabric: material("mara_rigged_sage_trousers", 0x78887c, 0.8, 0.0, 0.0),
	leather: material("mara_rigged_black_leather", 0x070707, 0.34, 0.0, 0.5),
	metal: material("mara_rigged_brass", 0xd0a24a, 0.3, 0.78, 0.0),
	hair: material("mara_rigged_dark_hair", 0x171312, 0.52, 0.0, 0.16),
	eye: material("mara_rigged_brown_eyes", 0x24160d, 0.4, 0.0, 0.0)
};

buildRiggedMara(scene, materials);

const exporter = new GLTFExporter();
const glb = await exporter.parseAsync(scene, {
	binary: true,
	onlyVisible: true,
	trs: false
});

await writeFile(outputPath, Buffer.from(glb));
console.log(`exported ${outputPath}`);

function material(name, color, roughness, metalness, clearcoat) {
	const mat = new THREE.MeshPhysicalMaterial({
		name,
		color,
		roughness,
		metalness,
		clearcoat,
		clearcoatRoughness: 0.4
	});
	mat.userData.godot_hint = "Three.js-authored original Mara rigged proxy material";
	return mat;
}

function buildRiggedMara(root, mats) {
	const proxy = new THREE.Group();
	proxy.name = "MaraRiggedProxy";
	root.add(proxy);

	const rig = createSkeleton();
	proxy.add(rig.bones.MaraRoot);

	const skeleton = new THREE.Skeleton(rig.orderedBones);
	const skinnedMeshes = [
		skinnedTube("mara_rigged_jacket", [
			ring([0, 0.84, 0], 0.22, 0.105, "MaraHips"),
			ring([0, 1.02, -0.006], 0.24, 0.12, "MaraSpine"),
			ring([0, 1.27, -0.01], 0.235, 0.135, "MaraChest"),
			ring([0, 1.45, -0.005], 0.18, 0.105, "MaraChest")
		], rig.index, mats.jacket, 24),
		skinnedTube("mara_rigged_shirt_panel", [
			ring([0, 0.92, -0.11], 0.105, 0.02, "MaraHips"),
			ring([0, 1.15, -0.135], 0.12, 0.025, "MaraSpine"),
			ring([0, 1.38, -0.13], 0.1, 0.022, "MaraChest")
		], rig.index, mats.shirt, 8),
		skinnedTube("mara_rigged_trousers", [
			ring([0, 0.62, 0], 0.18, 0.09, "MaraHips"),
			ring([0, 0.82, 0], 0.215, 0.11, "MaraHips")
		], rig.index, mats.fabric, 20),
		skinnedTube("mara_rigged_neck", [
			ring([0, 1.43, 0.012], 0.055, 0.045, "MaraNeck"),
			ring([0, 1.53, 0.014], 0.06, 0.05, "MaraNeck")
		], rig.index, mats.skin),
		skinnedTube("mara_rigged_head", [
			ring([0, 1.54, 0.01], 0.1, 0.08, "MaraHead"),
			ring([0, 1.62, -0.005], 0.14, 0.105, "MaraHead"),
			ring([0, 1.7, -0.005], 0.13, 0.098, "MaraHead"),
			ring([0, 1.75, 0], 0.095, 0.075, "MaraHead")
		], rig.index, mats.skin, 24),
		skinnedTube("mara_rigged_hair_mass", [
			ring([0, 1.58, 0.072], 0.13, 0.05, "MaraHead"),
			ring([0, 1.69, 0.052], 0.15, 0.07, "MaraHead"),
			ring([0, 1.77, 0.01], 0.12, 0.045, "MaraHead")
		], rig.index, mats.hair, 20),
		skinnedLimb("mara_rigged_upper_arm_l", [-0.2, 1.22, 0], [-0.255, 0.98, 0.015], 0.042, "MaraShoulderL", "MaraElbowL", rig.index, mats.jacket),
		skinnedLimb("mara_rigged_upper_arm_r", [0.2, 1.22, 0], [0.255, 0.98, 0.015], 0.042, "MaraShoulderR", "MaraElbowR", rig.index, mats.jacket),
		skinnedLimb("mara_rigged_forearm_l", [-0.255, 0.98, 0.015], [-0.305, 0.76, 0.03], 0.037, "MaraElbowL", "MaraHandL", rig.index, mats.jacket),
		skinnedLimb("mara_rigged_forearm_r", [0.255, 0.98, 0.015], [0.305, 0.76, 0.03], 0.037, "MaraElbowR", "MaraHandR", rig.index, mats.jacket),
		skinnedLimb("mara_rigged_hand_l", [-0.305, 0.76, 0.03], [-0.325, 0.68, 0.045], 0.036, "MaraHandL", "MaraHandL", rig.index, mats.skin, 8),
		skinnedLimb("mara_rigged_hand_r", [0.305, 0.76, 0.03], [0.325, 0.68, 0.045], 0.036, "MaraHandR", "MaraHandR", rig.index, mats.skin, 8),
		skinnedLimb("mara_rigged_thigh_l", [-0.105, 0.72, 0], [-0.115, 0.38, 0.018], 0.07, "MaraHipL", "MaraKneeL", rig.index, mats.fabric),
		skinnedLimb("mara_rigged_thigh_r", [0.105, 0.72, 0], [0.115, 0.38, 0.018], 0.07, "MaraHipR", "MaraKneeR", rig.index, mats.fabric),
		skinnedLimb("mara_rigged_shin_l", [-0.115, 0.38, 0.018], [-0.11, 0.09, 0.045], 0.059, "MaraKneeL", "MaraAnkleL", rig.index, mats.fabric),
		skinnedLimb("mara_rigged_shin_r", [0.115, 0.38, 0.018], [0.11, 0.09, 0.045], 0.059, "MaraKneeR", "MaraAnkleR", rig.index, mats.fabric),
		skinnedLimb("mara_rigged_boot_l", [-0.11, 0.09, -0.045], [-0.11, 0.045, -0.185], 0.064, "MaraAnkleL", "MaraToeL", rig.index, mats.leather, 10),
		skinnedLimb("mara_rigged_boot_r", [0.11, 0.09, -0.045], [0.11, 0.045, -0.185], 0.064, "MaraAnkleR", "MaraToeR", rig.index, mats.leather, 10)
	];

	for (const mesh of skinnedMeshes) {
		mesh.bind(skeleton);
		mesh.castShadow = true;
		mesh.receiveShadow = true;
		mesh.userData.mara_three_rigged_proxy = true;
		proxy.add(mesh);
	}

	addRigidDetail(proxy, "mara_rigged_eye_l", [0.052, 1.66, -0.145], 0.018, mats.eye, rig.bones.MaraHead);
	addRigidDetail(proxy, "mara_rigged_eye_r", [-0.052, 1.66, -0.145], 0.018, mats.eye, rig.bones.MaraHead);
	addRigidDetail(proxy, "mara_rigged_nose", [0, 1.62, -0.156], 0.024, mats.skin, rig.bones.MaraHead);
	addRigidDetail(proxy, "mara_rigged_pendant", [0, 1.01, -0.245], 0.042, mats.metal, rig.bones.MaraSpine);
	addRigidDetail(proxy, "mara_rigged_ear_l", [0.136, 1.63, -0.01], 0.026, mats.skin, rig.bones.MaraHead);
	addRigidDetail(proxy, "mara_rigged_ear_r", [-0.136, 1.63, -0.01], 0.026, mats.skin, rig.bones.MaraHead);
	addRigidDetail(proxy, "mara_rigged_earring_l", [0.152, 1.59, -0.018], 0.014, mats.metal, rig.bones.MaraHead);
	addAttachedBox(proxy, "mara_rigged_mouth", [0, 1.585, -0.158], [0.075, 0.009, 0.009], mats.jacketTrim, rig.bones.MaraHead);
	addAttachedBox(proxy, "mara_rigged_brow_l", [0.052, 1.695, -0.153], [0.056, 0.008, 0.008], mats.hair, rig.bones.MaraHead, [0, 0, 0.1]);
	addAttachedBox(proxy, "mara_rigged_brow_r", [-0.052, 1.695, -0.153], [0.056, 0.008, 0.008], mats.hair, rig.bones.MaraHead, [0, 0, -0.1]);
	addAttachedBox(proxy, "mara_rigged_hair_lock_l", [0.116, 1.58, -0.045], [0.03, 0.16, 0.035], mats.hair, rig.bones.MaraHead, [0.0, 0.0, -0.2]);
	addAttachedBox(proxy, "mara_rigged_hair_lock_r", [-0.116, 1.61, -0.04], [0.026, 0.12, 0.03], mats.hair, rig.bones.MaraHead, [0.0, 0.0, 0.18]);
	addAttachedBox(proxy, "mara_rigged_jacket_lapel_l", [0.068, 1.24, -0.145], [0.055, 0.32, 0.018], mats.jacketTrim, rig.bones.MaraChest, [0.0, 0.0, -0.34]);
	addAttachedBox(proxy, "mara_rigged_jacket_lapel_r", [-0.068, 1.24, -0.145], [0.055, 0.32, 0.018], mats.jacketTrim, rig.bones.MaraChest, [0.0, 0.0, 0.34]);
	addAttachedBox(proxy, "mara_rigged_belt", [0, 0.84, -0.12], [0.42, 0.035, 0.03], mats.leather, rig.bones.MaraHips);
	addAttachedBox(proxy, "mara_rigged_jacket_hem", [0, 0.86, -0.135], [0.4, 0.03, 0.024], mats.jacketTrim, rig.bones.MaraHips);
	addAttachedBox(proxy, "mara_rigged_cargo_pocket_l", [0.175, 0.52, -0.065], [0.075, 0.13, 0.028], mats.fabric, rig.bones.MaraHipL, [0, 0, -0.06]);
	addAttachedBox(proxy, "mara_rigged_cargo_pocket_r", [-0.175, 0.52, -0.065], [0.075, 0.13, 0.028], mats.fabric, rig.bones.MaraHipR, [0, 0, 0.06]);
	addAttachedBox(proxy, "mara_rigged_boot_sole_l", [-0.11, 0.0, -0.19], [0.15, 0.032, 0.2], mats.leather, rig.bones.MaraAnkleL);
	addAttachedBox(proxy, "mara_rigged_boot_sole_r", [0.11, 0.0, -0.19], [0.15, 0.032, 0.2], mats.leather, rig.bones.MaraAnkleR);
	addReplacementArm(proxy, "l", 1.0, mats);
	addReplacementArm(proxy, "r", -1.0, mats);
	addStrap(proxy, "mara_rigged_cross_body_strap", rig.index, skeleton, mats.leather);
}

function createSkeleton() {
	const bones = {};
	const root = bone("MaraRoot", [0, 0, 0]);
	bones.MaraRoot = root;
	bones.MaraHips = child(root, "MaraHips", [0, 0.82, 0]);
	bones.MaraSpine = child(bones.MaraHips, "MaraSpine", [0, 0.22, 0]);
	bones.MaraChest = child(bones.MaraSpine, "MaraChest", [0, 0.3, 0.01]);
	bones.MaraNeck = child(bones.MaraChest, "MaraNeck", [0, 0.15, 0.005]);
	bones.MaraHead = child(bones.MaraNeck, "MaraHead", [0, 0.12, 0.015]);
	bones.MaraShoulderL = child(bones.MaraChest, "MaraShoulderL", [-0.2, -0.12, 0]);
	bones.MaraElbowL = child(bones.MaraShoulderL, "MaraElbowL", [-0.055, -0.24, 0.015]);
	bones.MaraHandL = child(bones.MaraElbowL, "MaraHandL", [-0.05, -0.22, 0.015]);
	bones.MaraShoulderR = child(bones.MaraChest, "MaraShoulderR", [0.2, -0.12, 0]);
	bones.MaraElbowR = child(bones.MaraShoulderR, "MaraElbowR", [0.055, -0.24, 0.015]);
	bones.MaraHandR = child(bones.MaraElbowR, "MaraHandR", [0.05, -0.22, 0.015]);
	bones.MaraHipL = child(bones.MaraHips, "MaraHipL", [-0.105, -0.1, 0]);
	bones.MaraKneeL = child(bones.MaraHipL, "MaraKneeL", [-0.01, -0.34, 0.018]);
	bones.MaraAnkleL = child(bones.MaraKneeL, "MaraAnkleL", [0.005, -0.29, -0.027]);
	bones.MaraToeL = child(bones.MaraAnkleL, "MaraToeL", [0, -0.045, -0.14]);
	bones.MaraHipR = child(bones.MaraHips, "MaraHipR", [0.105, -0.1, 0]);
	bones.MaraKneeR = child(bones.MaraHipR, "MaraKneeR", [0.01, -0.34, 0.018]);
	bones.MaraAnkleR = child(bones.MaraKneeR, "MaraAnkleR", [-0.005, -0.29, -0.027]);
	bones.MaraToeR = child(bones.MaraAnkleR, "MaraToeR", [0, -0.045, -0.14]);

	const orderedBones = [];
	root.traverse((node) => {
		if (node.isBone) {
			orderedBones.push(node);
		}
	});
	const index = Object.fromEntries(orderedBones.map((item, i) => [item.name, i]));
	return { bones, orderedBones, index };
}

function bone(name, position) {
	const result = new THREE.Bone();
	result.name = name;
	result.position.fromArray(position);
	return result;
}

function child(parent, name, position) {
	const result = bone(name, position);
	parent.add(result);
	return result;
}

function ring(center, radiusX, radiusZ, boneName) {
	return { center, radiusX, radiusZ, boneName };
}

function skinnedTube(name, rings, boneIndex, mat, segments = 16) {
	const positions = [];
	const normals = [];
	const uvs = [];
	const skinIndices = [];
	const skinWeights = [];
	const indices = [];

	for (let r = 0; r < rings.length; r++) {
		const item = rings[r];
		for (let s = 0; s < segments; s++) {
			const angle = (s / segments) * Math.PI * 2;
			const nx = Math.cos(angle);
			const nz = Math.sin(angle);
			positions.push(
				item.center[0] + nx * item.radiusX,
				item.center[1],
				item.center[2] + nz * item.radiusZ
			);
			normals.push(nx, 0, nz);
			uvs.push(s / segments, r / Math.max(1, rings.length - 1));
			skinIndices.push(boneIndex[item.boneName], 0, 0, 0);
			skinWeights.push(1, 0, 0, 0);
		}
	}
	for (let r = 0; r < rings.length - 1; r++) {
		for (let s = 0; s < segments; s++) {
			const a = r * segments + s;
			const b = r * segments + ((s + 1) % segments);
			const c = (r + 1) * segments + s;
			const d = (r + 1) * segments + ((s + 1) % segments);
			indices.push(a, c, b, b, c, d);
		}
	}
	return skinnedMesh(name, positions, normals, uvs, indices, skinIndices, skinWeights, mat);
}

function skinnedLimb(name, start, end, radius, startBone, endBone, boneIndex, mat, segments = 14) {
	const positions = [];
	const normals = [];
	const uvs = [];
	const skinIndices = [];
	const skinWeights = [];
	const indices = [];
	const axis = new THREE.Vector3().fromArray(end).sub(new THREE.Vector3().fromArray(start));
	const up = Math.abs(axis.clone().normalize().dot(new THREE.Vector3(0, 1, 0))) > 0.92
		? new THREE.Vector3(1, 0, 0)
		: new THREE.Vector3(0, 1, 0);
	const side = new THREE.Vector3().crossVectors(axis, up).normalize();
	const forward = new THREE.Vector3().crossVectors(side, axis).normalize();
	for (let r = 0; r < 3; r++) {
		const t = r / 2;
		const center = new THREE.Vector3().fromArray(start).lerp(new THREE.Vector3().fromArray(end), t);
		const taper = 1 - Math.abs(t - 0.5) * 0.28;
		for (let s = 0; s < segments; s++) {
			const angle = (s / segments) * Math.PI * 2;
			const radial = side.clone().multiplyScalar(Math.cos(angle)).add(forward.clone().multiplyScalar(Math.sin(angle)));
			const pos = center.clone().add(radial.clone().multiplyScalar(radius * taper));
			positions.push(pos.x, pos.y, pos.z);
			normals.push(radial.x, radial.y, radial.z);
			uvs.push(s / segments, t);
			skinIndices.push(boneIndex[startBone], boneIndex[endBone], 0, 0);
			skinWeights.push(1 - t, t, 0, 0);
		}
	}
	for (let r = 0; r < 2; r++) {
		for (let s = 0; s < segments; s++) {
			const a = r * segments + s;
			const b = r * segments + ((s + 1) % segments);
			const c = (r + 1) * segments + s;
			const d = (r + 1) * segments + ((s + 1) % segments);
			indices.push(a, c, b, b, c, d);
		}
	}
	return skinnedMesh(name, positions, normals, uvs, indices, skinIndices, skinWeights, mat);
}

function skinnedMesh(name, positions, normals, uvs, indices, skinIndices, skinWeights, mat) {
	const geometry = new THREE.BufferGeometry();
	geometry.setAttribute("position", new THREE.Float32BufferAttribute(positions, 3));
	geometry.setAttribute("normal", new THREE.Float32BufferAttribute(normals, 3));
	geometry.setAttribute("uv", new THREE.Float32BufferAttribute(uvs, 2));
	geometry.setAttribute("skinIndex", new THREE.Uint16BufferAttribute(skinIndices, 4));
	geometry.setAttribute("skinWeight", new THREE.Float32BufferAttribute(skinWeights, 4));
	geometry.setIndex(indices);
	geometry.computeBoundingSphere();
	const mesh = new THREE.SkinnedMesh(geometry, mat);
	mesh.name = name;
	mesh.frustumCulled = false;
	return mesh;
}

function addRigidDetail(parent, name, position, radius, mat, attachBone) {
	const mesh = new THREE.Mesh(new THREE.SphereGeometry(radius, 16, 10), mat);
	mesh.name = name;
	mesh.position.fromArray(position);
	mesh.castShadow = true;
	mesh.receiveShadow = true;
	attachBone.attach(mesh);
}

function addReplacementArm(parent, suffix, side, mats) {
	addSpherePart(parent, `mara_three_replacement_shoulder_cap_${suffix}`, [0.24 * side, 1.365, 0], 0.058, mats.jacket);
	addCapsulePart(parent, `mara_three_replacement_upper_arm_${suffix}`, [0.255 * side, 1.22, 0], 0.047, 0.31, mats.jacket);
	addCapsulePart(parent, `mara_three_replacement_forearm_${suffix}`, [0.275 * side, 0.93, 0.01], 0.04, 0.28, mats.jacket);
	addCapsulePart(parent, `mara_three_replacement_hand_${suffix}`, [0.28 * side, 0.72, 0.025], 0.04, 0.055, mats.skin);
}

function addCapsulePart(parent, name, position, radius, length, mat) {
	const mesh = new THREE.Mesh(new THREE.CapsuleGeometry(radius, length, 16, 24), mat);
	mesh.name = name;
	mesh.position.fromArray(position);
	mesh.castShadow = true;
	mesh.receiveShadow = true;
	mesh.userData.mara_three_rigged_replacement_arm = true;
	parent.add(mesh);
	return mesh;
}

function addSpherePart(parent, name, position, radius, mat) {
	const mesh = new THREE.Mesh(new THREE.SphereGeometry(radius, 18, 12), mat);
	mesh.name = name;
	mesh.position.fromArray(position);
	mesh.castShadow = true;
	mesh.receiveShadow = true;
	mesh.userData.mara_three_rigged_replacement_arm = true;
	parent.add(mesh);
	return mesh;
}

function addAttachedBox(parent, name, position, size, mat, attachBone, rotation = [0, 0, 0]) {
	const mesh = new THREE.Mesh(new THREE.BoxGeometry(size[0], size[1], size[2]), mat);
	mesh.name = name;
	mesh.position.fromArray(position);
	mesh.rotation.fromArray(rotation);
	mesh.castShadow = true;
	mesh.receiveShadow = true;
	attachBone.attach(mesh);
	return mesh;
}

function addStrap(parent, name, boneIndex, skeleton, mat) {
	const mesh = skinnedTube(name, [
		ring([-0.16, 1.42, -0.15], 0.018, 0.012, "MaraChest"),
		ring([-0.06, 1.25, -0.16], 0.018, 0.012, "MaraChest"),
		ring([0.05, 1.08, -0.16], 0.018, 0.012, "MaraSpine"),
		ring([0.14, 0.9, -0.14], 0.018, 0.012, "MaraHips")
	], boneIndex, mat, 8);
	mesh.bind(skeleton);
	mesh.castShadow = true;
	mesh.receiveShadow = true;
	mesh.userData.mara_three_rigged_proxy = true;
	parent.add(mesh);
}
