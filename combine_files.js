const fs = require('node:fs/promises')
const path = require('node:path')


// Simple function to combine all the sql files in order by 
// the list in sql-scripts.json into a single file

async function combine_Files() {

    // Get file list path
    const fileListPath = path.join(__dirname, 'sql-scripts.json')

    // Read contents into string
    const fileList = await fs.readFile(fileListPath, 'utf8')

    // Convert to json
    const jsonList = await JSON.parse(fileList);
   
    // Cycle through list for each file
    const completed_File = await Promise.all(
        // Read the File Contents
        // Copy into a new string
        jsonList.scripts.map((file) => fs.readFile(file, 'utf8'))
    )

    if (completed_File != '') {  
        const outputPath = path.join(__dirname, 'output', `SMTA Complete Script - ${Date.now()}.sql`)
        await fs.writeFile(outputPath, completed_File)
        console.log(`${jsonList.scripts.length} files combined into ${outputPath}`)
    } else {
        console.log ('Sorry, something went wrong - no file created.')
    }

}


combine_Files();