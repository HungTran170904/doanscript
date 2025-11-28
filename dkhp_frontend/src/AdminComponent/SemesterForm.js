import { Col, Form, Row } from "react-bootstrap";

const SemesterForm=({semesterDTO})=>{
          function handleOnChange(e, fieldName){
                   semesterDTO[fieldName]=parseInt(e.target.value);
          }
          return(
                    <Form>
                              <Row className="mb-3">
                                        <Form.Group as={Col} controlId="semesterNum">
                                                  <Form.Label>Học Kì</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"semesterNum")}/>
                                        </Form.Group>
                                        <Form.Group as={Col} controlId="year">
                                                  <Form.Label>Năm</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"year")}/>
                                        </Form.Group>
                              </Row>
                    </Form>
          )
}
export default SemesterForm;