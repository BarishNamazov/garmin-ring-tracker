import java.io.File;
import java.io.InputStream;
import java.security.MessageDigest;

import org.apache.commons.compress.archivers.sevenz.SevenZArchiveEntry;
import org.apache.commons.compress.archivers.sevenz.SevenZFile;

final class IqPrgHashes {
    private static String hex(byte[] value) {
        StringBuilder result = new StringBuilder(value.length * 2);
        for (byte part : value) {
            result.append(String.format("%02x", part & 0xff));
        }
        return result.toString();
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("usage: IqPrgHashes <package.iq>");
        }
        try (SevenZFile archive = SevenZFile.builder().setFile(new File(args[0])).get()) {
            for (SevenZArchiveEntry entry : archive.getEntries()) {
                if (entry.isDirectory() || !entry.getName().endsWith(".prg")) {
                    continue;
                }
                MessageDigest digest = MessageDigest.getInstance("SHA-256");
                try (InputStream input = archive.getInputStream(entry)) {
                    byte[] buffer = new byte[8192];
                    for (int count; (count = input.read(buffer)) != -1;) {
                        digest.update(buffer, 0, count);
                    }
                }
                System.out.println(hex(digest.digest()) + "  IQ:" + entry.getName());
            }
        }
    }
}
