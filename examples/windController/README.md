Wind controller example
=======================

This is the example described in Section 2.1 of the [initial Vehicle paper](https://arxiv.org/abs/2202.05207v1). The neural network used to implement the controller is `controller.onnx`. The Vehicle specification describing its behavious is `windController.vcl`.

Verifying using Marabou
-----------------------

The controller can be verified against the specification by running the following command:
```bash
vehicle verify \
  --specification examples/windController/windController.vcl \
  --network controller:examples/windController/controller.onnx \
  --verifier Marabou \
  --proofCache examples/windController/windController.vclp
```
where the last line tells Vehicle where to write out the proof cache which can
then be used by Agda in the next step.

(Optional) If you would like to see the intermediate Marabou queries generated, you can
run the following command:
```bash
vehicle compile \
  --target Marabou \
  --specification examples/windController/windController.vcl \
  --outputFile examples/windController/windController-queries \
  --network controller:examples/windController/controller.onnx
```
which will put them in the `windController-queries` folder.

Compiling to specification to Agda
----------------------------------

The (verified) specification may then be compiled to Agda by running the command:
```bash
vehicle compile \
  --target Agda \
  --specification examples/windController/windController.vcl \
  --outputFile examples/windController/agdaProof/WindControllerSpec.agda \
  --proofCache examples/windController/windController.vclp
```

The full proof safety which makes uses of the generated Agda version of the specification in `agdaProof/WindControllerSpec.agda` is found in `agdaProof/SafetyProof.agda`.
