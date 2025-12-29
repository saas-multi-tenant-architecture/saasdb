const fs = require('node:fs/promises')
const path = require('node:path')


// Simple function to combine all the sql files in order by 
// the list in sql-scripts.json into a single file

async function combine_Files() {

    // Get file list path
    const fileListPath = path.join(__dirname, 'sql-scripts.json')

    // Read list of files
    const fileList = await fs.readFile(fileListPath, 'utf8')

    // Convert list of tiles to json
    const jsonList = await JSON.parse(fileList);
   
    // Cycle through list for each file
    const parts = await Promise.all(
        // Read the File Contents
        // Copy into a new string array
        jsonList.scripts.map((file) => fs.readFile(file, 'utf8'))
    );

    // Separate each file by a string
    const completed_File = parts.join('\n\n-- =============== NEW FILE =================\n\n');

    if (completed_File.length > 0) {  
        const outputPath = path.join(__dirname, 'output', `SMTA Complete Script - ${Date.now()}.sql`)
        await fs.writeFile(outputPath, completed_File, 'utf8')
        console.log(`${jsonList.scripts.length} files combined into ${outputPath}`)
    } else {
        console.log ('Sorry, something went wrong - no file created.')
    }

}


combine_Files();