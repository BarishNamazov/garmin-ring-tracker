import java.io.File;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.apache.commons.compress.archivers.sevenz.SevenZArchiveEntry;
import org.apache.commons.compress.archivers.sevenz.SevenZFile;

final class ExtractIqPrgs {
    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            throw new IllegalArgumentException("usage: ExtractIqPrgs <package.iq> <device-parts.tsv> <output-dir>");
        }
        Map<String, String> devicesByPart = new HashMap<>();
        for (String line : Files.readAllLines(Path.of(args[1]))) {
            String[] fields = line.split("\t", -1);
            if (fields.length != 2 || fields[0].isEmpty() || fields[1].isEmpty()
                    || devicesByPart.putIfAbsent(fields[1], fields[0]) != null) {
                throw new IllegalArgumentException("Invalid or duplicate part mapping: " + line);
            }
        }
        Path outputDir = Path.of(args[2]);
        Files.createDirectories(outputDir);
        Set<String> extracted = new HashSet<>();
        try (SevenZFile archive = SevenZFile.builder().setFile(new File(args[0])).get()) {
            for (SevenZArchiveEntry entry : archive.getEntries()) {
                if (entry.isDirectory() || !entry.getName().endsWith(".prg")) {
                    continue;
                }
                String name = entry.getName();
                int slash = name.indexOf('/');
                if (slash < 0) {
                    continue;
                }
                String device = devicesByPart.get(name.substring(0, slash));
                if (device == null) {
                    continue;
                }
                if (!extracted.add(device)) {
                    throw new IllegalStateException("Multiple PRGs for device " + device);
                }
                try (InputStream input = archive.getInputStream(entry)) {
                    Files.write(outputDir.resolve("RingTracker-" + device + ".prg"), input.readAllBytes());
                }
            }
        }
        if (extracted.size() != devicesByPart.size()) {
            Set<String> missing = new HashSet<>(devicesByPart.values());
            missing.removeAll(extracted);
            throw new IllegalStateException("No PRG in IQ package for " + missing);
        }
        System.out.println("Extracted " + extracted.size() + " signed device PRGs from IQ package.");
    }
}
