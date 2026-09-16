import java.io.File;
import java.io.InputStream;
import java.security.MessageDigest;

import org.apache.commons.compress.archivers.sevenz.SevenZArchiveEntry;
import org.apache.commons.compress.archivers.sevenz.SevenZFile;

final class IqPrgHashes {
    // monkeyc appends this key-dependent block when signing with the documented
    // 4096-bit RSA key. Payload mode keeps the fixed header and omits the block.
    private static final int SIGNING_TRAILER_SIZE = 1548;
    private static final int SIGNING_HEADER_SIZE = 8;
    private static final byte[] SIGNING_MAGIC = {
        (byte) 0xe1, (byte) 0xc0, (byte) 0xde, (byte) 0x12
    };

    private static String hex(byte[] value) {
        StringBuilder result = new StringBuilder(value.length * 2);
        for (byte part : value) {
            result.append(String.format("%02x", part & 0xff));
        }
        return result.toString();
    }

    public static void main(String[] args) throws Exception {
        boolean payloadOnly = args.length == 2 && args[0].equals("--payload");
        if ((!payloadOnly && args.length != 1) || (payloadOnly && args.length != 2)) {
            throw new IllegalArgumentException(
                "usage: IqPrgHashes [--payload] <package.iq>");
        }
        String packagePath = args[payloadOnly ? 1 : 0];
        try (SevenZFile archive = SevenZFile.builder().setFile(new File(packagePath)).get()) {
            for (SevenZArchiveEntry entry : archive.getEntries()) {
                if (entry.isDirectory() || !entry.getName().endsWith(".prg")) {
                    continue;
                }
                MessageDigest digest = MessageDigest.getInstance("SHA-256");
                try (InputStream input = archive.getInputStream(entry)) {
                    byte[] data = input.readAllBytes();
                    int digestLength = data.length;
                    if (payloadOnly) {
                        if (digestLength <= SIGNING_TRAILER_SIZE + SIGNING_HEADER_SIZE) {
                            throw new IllegalArgumentException(
                                "PRG is too short to contain a signing trailer: " + entry.getName());
                        }
                        digestLength -= SIGNING_TRAILER_SIZE;
                        for (int index = 0; index < SIGNING_MAGIC.length; index++) {
                            if (data[digestLength - SIGNING_HEADER_SIZE + index]
                                    != SIGNING_MAGIC[index]) {
                                throw new IllegalArgumentException(
                                    "Unrecognized PRG signing trailer: " + entry.getName());
                            }
                        }
                    }
                    digest.update(data, 0, digestLength);
                }
                System.out.println(hex(digest.digest()) + "  IQ:" + entry.getName());
            }
        }
    }
}
