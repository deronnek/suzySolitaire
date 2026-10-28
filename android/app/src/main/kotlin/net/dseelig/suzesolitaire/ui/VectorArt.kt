package net.dseelig.suzesolitaire.ui

import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.Shader
import java.nio.ByteBuffer

// A card face as scripts/import-cards.py writes it: the SVG flattened by Android Studio's converter into paths, clips
// and gradient fills, then written as numbers (the format is described there).  Android's VectorDrawable can't take the
// face cards, since compiled resource XML can't hold a string over 32,767 characters and their line art is one path
// several times that long, and reading the SVGs or the converter's XML took seconds, where these read in a moment.
class VectorArt private constructor(private val width: Float, private val height: Float, private val root: List<Node>) {

    private sealed interface Node
    private class Group(val children: List<Node>) : Node
    private class Clip(val path: Path) : Node
    private class Shape(val path: Path, val fill: Paint?, val stroke: Paint?) : Node

    // Draws the art filling a canvas of the given size
    fun draw(canvas: Canvas, widthPx: Int, heightPx: Int) {
        canvas.save()
        canvas.scale(widthPx / width, heightPx / height)
        draw(canvas, root)
        canvas.restore()
    }

    private fun draw(canvas: Canvas, nodes: List<Node>) {
        for (node in nodes) {
            when (node) {
                is Group -> {
                    canvas.save()
                    draw(canvas, node.children)
                    canvas.restore()
                }
                is Clip -> canvas.clipPath(node.path)
                is Shape -> {
                    node.fill?.let { canvas.drawPath(node.path, it) }
                    node.stroke?.let { canvas.drawPath(node.path, it) }
                }
            }
        }
    }

    companion object {
        private const val END = 0
        private const val GROUP = 1
        private const val GROUP_END = 2
        private const val CLIP = 3
        private const val SHAPE = 4

        fun read(bytes: ByteArray): VectorArt {
            check(String(bytes, 0, 4) == "SUZ1") { "Not a card file" }
            val buffer = ByteBuffer.wrap(bytes, 4, bytes.size - 4)
            val width = buffer.float
            val height = buffer.float
            return VectorArt(width, height, Reader(buffer).nodes())
        }

        private class Reader(val buffer: ByteBuffer) {
            private var x = 0
            private var y = 0

            // Nodes up to the end of the file or of the group they're in
            fun nodes(): List<Node> {
                val nodes = mutableListOf<Node>()
                while (true) {
                    when (buffer.get().toInt()) {
                        END, GROUP_END -> return nodes
                        GROUP -> nodes.add(Group(nodes()))
                        CLIP -> nodes.add(Clip(path(evenOdd = false)))
                        SHAPE -> nodes.add(shape())
                    }
                }
            }

            private fun shape(): Shape {
                val flags = buffer.get().toInt()
                val fill = if (flags and 2 != 0) Paint(Paint.ANTI_ALIAS_FLAG).apply { color = buffer.int } else null
                val gradient = if (flags and 4 != 0) Paint(Paint.ANTI_ALIAS_FLAG).apply { shader = gradient() } else null
                val stroke = if (flags and 8 != 0) Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    color = buffer.int
                    strokeWidth = buffer.float
                    strokeJoin = when (buffer.get().toInt()) {
                        1 -> Paint.Join.ROUND
                        2 -> Paint.Join.BEVEL
                        else -> Paint.Join.MITER
                    }
                } else null
                return Shape(path(evenOdd = flags and 1 != 0), fill ?: gradient, stroke)
            }

            private fun gradient(): Shader {
                val radial = buffer.get().toInt() == 1
                val points = FloatArray(if (radial) 3 else 4) { buffer.float }
                val count = buffer.get().toInt()
                val offsets = FloatArray(count)
                val colors = IntArray(count)
                for (i in 0 until count) {
                    offsets[i] = buffer.float
                    colors[i] = buffer.int
                }
                return if (radial) RadialGradient(points[0], points[1], points[2], colors, offsets, Shader.TileMode.CLAMP)
                else LinearGradient(points[0], points[1], points[2], points[3], colors, offsets, Shader.TileMode.CLAMP)
            }

            // Each path's coordinates start from 0, 0
            private fun path(evenOdd: Boolean): Path {
                x = 0
                y = 0
                val path = Path()
                path.fillType = if (evenOdd) Path.FillType.EVEN_ODD else Path.FillType.WINDING
                while (true) {
                    when (buffer.get().toInt().toChar()) {
                        'M' -> path.moveTo(nextX(), nextY())
                        'L' -> path.lineTo(nextX(), nextY())
                        'Q' -> path.quadTo(nextX(), nextY(), nextX(), nextY())
                        'C' -> path.cubicTo(nextX(), nextY(), nextX(), nextY(), nextX(), nextY())
                        'Z' -> path.close()
                        else -> return path
                    }
                }
            }

            // Each coordinate is the change from the last one, in hundredths, as a zigzag varint
            private fun nextX(): Float {
                x += varint()
                return x / 100f
            }

            private fun nextY(): Float {
                y += varint()
                return y / 100f
            }

            private fun varint(): Int {
                var result = 0L
                var shift = 0
                while (true) {
                    val byte = buffer.get().toInt()
                    result = result or ((byte and 0x7f).toLong() shl shift)
                    if (byte and 0x80 == 0) {
                        break
                    }
                    shift += 7
                }
                return ((result ushr 1) xor -(result and 1)).toInt()
            }
        }
    }
}
