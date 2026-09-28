---
name: sequential-image-extractor
description: Extract text, tables, code, and structural information from a sequence of images in a folder sorted naturally by numbers in their filenames. Save each image's extracted information as a separate markdown/text file, and compile a final summary file.
---

# Sequential Image Extractor Skill

Use this skill when the user wants to extract information from a series of images (e.g., screenshots of slides, pages of a document, frames, code snippets) in a folder that are ordered sequentially by numbers in their filenames, and write both individual extracted files and a summary file.

## Execution Workflow

Follow these steps to perform the extraction and summarization:

### 1. Identify Target Directory and Format Preferences
- Ask the user for the path of the directory containing the target images if they haven't provided it.
- Confirm if they want the output saved in a subfolder (e.g. `extracted_info`) or directly in the same folder. Default to creating an `extracted_info` subfolder in the same directory.
- Confirm if they have a preference for the output files' extension (default is `.md` to support rich formatting like code blocks and tables).

### 2. Retrieve and Sort Image Files
- Use a run-command tool to run the python helper script `C:/Users/hyunwookim/.agents/skills/sequential-image-extractor/scripts/sort_images.py` with the target directory path as an argument.
  - Example command: `python "C:/Users/hyunwookim/.agents/skills/sequential-image-extractor/scripts/sort_images.py" "C:/path/to/image/folder"`
- The script outputs the absolute paths of all image files in the directory sorted naturally by the numbers in their filenames (e.g., `slide_2.png` will sort before `slide_10.png`).
- Parse the output list and keep the images in that exact sequence.

### 3. Extract Information from Each Image
For each image in the sorted sequence:
1. Open and view the image using the `read_file` tool.
2. Read the image content and extract all relevant text, data, and structure.
3. **Preserve the original formatting**:
   - If the image contains structured data (like tables), extract it as a markdown table.
   - If the image contains code, extract it as a fenced code block with appropriate syntax highlighting.
   - If it has bullet points or headers, use markdown lists and headers to match the hierarchy.
   - Preserve paragraphs, line breaks, and relative layout structure where logical.
4. Save this extracted content to a separate file in the output directory.
   - The file name should match the base name of the image (e.g., if the image is `slide_01.png`, the extracted file should be `slide_01.md`).
   - If a file already exists, overwrite it or append based on context, but typically write a clean new file.

### 4. Create the Summary Document
Once all images are processed, compile a summary file (e.g., `summary.md`) in the output directory. The summary file should contain:
- **Title and Overview**: An introduction summarizing the overall content of the image sequence.
- **Sequential Table of Contents**: A markdown table listing each image/extraction file in order:
  | Sequence | Original File | Extracted File | Brief Content Summary |
  |---|---|---|---|
- **Synthesized Summary**: A high-level analysis of the entire sequence, highlighting key themes, logical flow, or critical takeaways from the combined slides/pages.

## Verification
- Confirm that the number of output text files matches the number of scanned images.
- Verify that the summary file links to all the individual extraction files correctly.
- Review a sample of the extracted text files to ensure the layout, code syntax, or tables were correctly transcribed.
