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
  if (!Array.isArray(manifest.scripts)) {
    throw new Error(`sql-scripts.json in ${packageDir} is missing a "scripts" array`)
  }
  return manifest.scripts.map(file => {
    if (path.isAbsolute(file) || file.includes('..')) {
      throw new Error(`Unsafe path in sql-scripts.json: "${file}"`)
    }
    return path.join(packageDir, file)
  })
}

async function deploy() {
  const adapterIdx = process.argv.indexOf('--adapter')
  const adapterName = adapterIdx !== -1 ? process.argv[adapterIdx + 1] : 'supabase'
  const enableGraphql = process.argv.includes('--enable-graphql')

  if (adapterIdx !== -1 && !adapterName) {
    console.error('--adapter requires a value.')
    process.exit(1)
  }

  if (!ADAPTERS.includes(adapterName)) {
    console.error(`Unknown adapter "${adapterName}". Valid adapters: ${ADAPTERS.join(', ')}`)
    process.exit(1)
  }

  const coreDir = resolvePackageDir('@smta/core')
  const adapterDir = resolvePackageDir(`@smta/${adapterName}`)

  const corePaths = await readPackageScripts(coreDir)
  const adapterPaths = await readPackageScripts(adapterDir)
  let allPaths = [...corePaths, ...adapterPaths]

  if (enableGraphql) {
    allPaths = allPaths.filter(p => !p.endsWith(path.join('graphql', 'disable_extension.sql')))
    console.log('--enable-graphql: pg_graphql extension will not be dropped.')
  }

  if (allPaths.length === 0) {
    console.error('No SQL scripts found in manifests.')
    process.exit(1)
  }

  const parts = await Promise.all(allPaths.map(f => fs.readFile(f, 'utf8')))
  const combined = parts.join('\n\n-- =============== NEW FILE =================\n\n')

  const outputPath = path.join(process.cwd(), `SMTA-${adapterName}-${Date.now()}.sql`)
  await fs.writeFile(outputPath, combined, 'utf8')
  console.log(`${allPaths.length} files combined into ${outputPath}`)
}

deploy().catch(err => {
  console.error(`Deploy failed: ${err.message}`)
  process.exit(1)
})
