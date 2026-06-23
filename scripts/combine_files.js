const fs = require('node:fs/promises')
const path = require('node:path')

const ADAPTERS = ['supabase', 'payload', 'better-auth']
const ROOT = path.join(__dirname, '..')

async function readPackageScripts(packageDir, variant) {
  const manifestPath = path.join(packageDir, 'sql-scripts.json')
  const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'))
  if (!Array.isArray(manifest.scripts)) {
    throw new Error(`sql-scripts.json in ${packageDir} is missing a "scripts" array`)
  }
  return manifest.scripts
    .map(entry => (typeof entry === 'string' ? { file: entry } : entry))
    .filter(entry => !entry.variant || entry.variant === variant)
    .map(entry => {
      if (path.isAbsolute(entry.file) || entry.file.includes('..')) {
        throw new Error(`Unsafe path in sql-scripts.json: "${entry.file}"`)
      }
      return path.join(packageDir, entry.file)
    })
}

async function combineFiles() {
  const adapterIdx = process.argv.indexOf('--adapter')
  const adapterName = adapterIdx !== -1 ? process.argv[adapterIdx + 1] : 'supabase'

  if (!ADAPTERS.includes(adapterName)) {
    console.error(`Unknown adapter "${adapterName}". Valid adapters: ${ADAPTERS.join(', ')}`)
    process.exit(1)
  }

  let betterAuthIds = null
  if (adapterName === 'better-auth') {
    const idsIdx = process.argv.indexOf('--better-auth-ids')
    betterAuthIds = idsIdx !== -1 ? process.argv[idsIdx + 1] : null
    if (!betterAuthIds || !['uuid', 'mapped'].includes(betterAuthIds)) {
      console.error(
        '--adapter better-auth requires --better-auth-ids <uuid|mapped>.\n' +
        "  uuid   = Better-Auth configured to emit UUID ids (advanced.database.generateId). Fastest; no mapping table.\n" +
        '  mapped = SMTA maps Better-Auth string ids to UUIDs via core.user_identities (no Better-Auth config).'
      )
      process.exit(1)
    }
  }

  const coreDir = path.join(ROOT, 'packages', 'core')
  const adapterDir = path.join(ROOT, 'packages', adapterName)

  const enableGraphql = process.argv.includes('--enable-graphql')

  const corePaths = await readPackageScripts(coreDir)
  const adapterPaths = await readPackageScripts(adapterDir, betterAuthIds)
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
