import com.android.ide.common.vectordrawable.Svg2Vector
import java.io.File

// Main <svg folder> <out folder>: converts every .svg in the folder into a VectorDrawable .xml of the same name, and
// prints any warnings other than the converter's note that stroke widths under a non-uniform scale are approximate
fun main(args: Array<String>) {
    val out = File(args[1]).apply { mkdirs() }
    var converted = 0
    for (svg in File(args[0]).listFiles { file -> file.extension == "svg" }!!.sorted()) {
        val warnings = File(out, svg.nameWithoutExtension + ".xml").outputStream().use { Svg2Vector.parseSvgToXml(svg.toPath(), it) }
        warnings.lines().filter { it.isNotBlank() && "stroke width is approximate" !in it }.distinct().forEach { println("${svg.name}: $it") }
        converted += 1
    }
    println("Converted $converted SVGs")
}
