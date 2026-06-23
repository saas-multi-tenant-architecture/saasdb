const fs = require('node:fs/promises')
const path = require('node:path')

const ADAPTERS = ['supabase', 'payload', 'better-auth']
const ROOT = path.join(__dirname, '..')

async function readPackageScripts(packageDir) {
  const manifestPath = path.join(packageDir, 'sql-scripts.json')
  const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'))
  return manifest.scripts.map(file => path.join(packageDir, file))
}

async function combineFiles() {
  const adapterIdx = process.argv.indexOf('--adapter')
  const adapterName = adapterIdx !== -1 ? process.argv[adapterIdx + 1] : 'supabase'

  if (!ADAPTERS.includes(adapterName)) {
    console.error(`Unknown adapter "${adapterName}". Valid adapters: ${ADAPTERS.join(', ')}`)
    process.exit(1)
  }

  const coreDir = path.join(ROOT, 'packages', 'core')
  const adapterDir = path.join(ROOT, 'packages', adapterName)

  const enableGraphql = process.argv.includes('--enable-graphql')

  const corePaths = await readPackageScripts(coreDir)
  const adapterPaths = await readPackageScripts(adapterDir)
  let allPaths = [...corePaths, ...adapterPaths]

  if (enableGraphql) {
    allPaths = allPaths.filter(p => !p.endsWith('disable_graphql.sql'))
    console.log('--enable-graphql: pg_graphql extension will not be dropped.')
  }

  const parts = await Promise.all(allPaths.map(f => fs.readFile(f, 'utf8')))
  const combined = parts.join('\n\n-- =============== NEW FILE =================\n\n')

  if (combined.length > 0) {
    const outputPath = path.join(ROOT, 'output', `SMTA-${adapterName}-${Date.now()}.sql`)
    await fs.writeFile(outputPath, combined, 'utf8')
    console.log(`${allPaths.length} files combined into ${outputPath}`)
  } else {
    console.error('Something went wrong — no file created.')
    process.exit(1)
  }
}

combineFiles()
