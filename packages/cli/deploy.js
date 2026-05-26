#!/usr/bin/env node
'use strict'

const fs = require('node:fs/promises')
const path = require('node:path')

const ADAPTERS = ['supabase', 'payload']

function resolvePackageDir(packageName) {
  const manifestPath = require.resolve(`${packageName}/package.json`)
  return path.dirname(manifestPath)
}

async function readPackageScripts(packageDir) {
  const manifestPath = path.join(packageDir, 'sql-scripts.json')
  const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'))
  return manifest.scripts.map(file => path.join(packageDir, file))
}

async function deploy() {
  const adapterIdx = process.argv.indexOf('--adapter')
  const adapterName = adapterIdx !== -1 ? process.argv[adapterIdx + 1] : 'supabase'

  if (!ADAPTERS.includes(adapterName)) {
    console.error(`Unknown adapter "${adapterName}". Valid adapters: ${ADAPTERS.join(', ')}`)
    process.exit(1)
  }

  const coreDir = resolvePackageDir('@smta/core')
  const adapterDir = resolvePackageDir(`@smta/${adapterName}`)

  const corePaths = await readPackageScripts(coreDir)
  const adapterPaths = await readPackageScripts(adapterDir)
  const allPaths = [...corePaths, ...adapterPaths]

  const parts = await Promise.all(allPaths.map(f => fs.readFile(f, 'utf8')))
  const combined = parts.join('\n\n-- =============== NEW FILE =================\n\n')

  if (combined.length === 0) {
    console.error('Something went wrong — no content to write.')
    process.exit(1)
  }

  const outputPath = path.join(process.cwd(), `SMTA-${adapterName}-${Date.now()}.sql`)
  await fs.writeFile(outputPath, combined, 'utf8')
  console.log(`${allPaths.length} files combined into ${outputPath}`)
}

deploy()
